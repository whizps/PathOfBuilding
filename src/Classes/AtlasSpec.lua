local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_sort = table.sort
local t_concat = table.concat

local AtlasSpecClass = newClass("AtlasSpec", "UndoHandler")

function AtlasSpecClass:AtlasSpec(key, title)
	self:UndoHandler()
	self.title = title or "Default"
	self:ApplyState(key, { }, { })
	self:ResetUndo()
	return self
end

function AtlasSpecClass:GetAllocatedIds()
	local ids = { }
	for id, node in pairs(self.allocNodes) do
		if node.type ~= "Root" then
			t_insert(ids, id)
		end
	end
	t_sort(ids)
	return ids
end

function AtlasSpecClass:ApplyState(key, ids, variants)
	self.tree = main:LoadAtlasTree(key)
	self.treeVersion = self.tree.key
	self.allocNodes = { }
	for _, node in ipairs(self.tree.startNodes) do
		self.allocNodes[node.id] = node
	end
	local dropped = 0
	for _, id in ipairs(ids) do
		local node = self.tree.nodes[id]
		if node and node.type ~= "Mastery" and node.type ~= "Root" then
			self.allocNodes[id] = node
		elseif not node then
			dropped = dropped + 1
		end
	end
	local before = #self:GetAllocatedIds()
	self:PruneDisconnected()
	dropped = dropped + before - #self:GetAllocatedIds()
	self.variantSelections = { }
	for nodeId, effect in pairs(variants) do
		self:SetVariant(nodeId, effect)
	end
	self:Invalidate()
	return dropped
end

function AtlasSpecClass:Invalidate()
	self.statSummary = nil
	self.revision = (self.revision or 0) + 1
end

function AtlasSpecClass:FindConnected(excluded)
	local reached = { }
	local queue = { }
	for _, node in ipairs(self.tree.startNodes) do
		if node ~= excluded then
			reached[node] = true
			t_insert(queue, node)
		end
	end
	local index = 1
	while queue[index] do
		local node = queue[index]
		index = index + 1
		for _, other in ipairs(node.linked) do
			if not reached[other] and other ~= excluded and self.allocNodes[other.id] then
				reached[other] = true
				t_insert(queue, other)
			end
		end
	end
	return reached
end

function AtlasSpecClass:PruneDisconnected()
	local reached = self:FindConnected()
	for id, node in pairs(self.allocNodes) do
		if not reached[node] then
			self.allocNodes[id] = nil
			self.variantSelections[id] = nil
		end
	end
end

function AtlasSpecClass:GetPathToNode(target)
	if not target or self.allocNodes[target.id] or target.type == "Mastery" or target.type == "Root" then
		return { }
	end
	local previous = { }
	local queue = { }
	for _, node in pairs(self.allocNodes) do
		previous[node] = false
		t_insert(queue, node)
	end
	local index = 1
	while queue[index] and previous[target] == nil do
		local node = queue[index]
		index = index + 1
		for _, other in ipairs(node.linked) do
			if previous[other] == nil and other.type ~= "Mastery" then
				previous[other] = node
				t_insert(queue, other)
			end
		end
	end
	if previous[target] == nil then
		return { }
	end
	local reversed = { }
	local node = target
	while node and not self.allocNodes[node.id] do
		t_insert(reversed, node)
		node = previous[node]
	end
	local path = { }
	for i = #reversed, 1, -1 do
		t_insert(path, reversed[i])
	end
	return path
end

function AtlasSpecClass:AllocNode(node)
	local path = self:GetPathToNode(node)
	for _, pathNode in ipairs(path) do
		self.allocNodes[pathNode.id] = pathNode
	end
	if #path > 0 then
		self:Invalidate()
	end
	return #path > 0
end

function AtlasSpecClass:GetDependents(node)
	if not node or not self.allocNodes[node.id] or node.type == "Root" then
		return { }
	end
	local reached = self:FindConnected(node)
	local dependents = { }
	for _, allocated in pairs(self.allocNodes) do
		if not reached[allocated] then
			t_insert(dependents, allocated)
		end
	end
	return dependents
end

function AtlasSpecClass:DeallocNode(node)
	local dependents = self:GetDependents(node)
	for _, dependent in ipairs(dependents) do
		self.allocNodes[dependent.id] = nil
		self.variantSelections[dependent.id] = nil
	end
	if #dependents > 0 then
		self:Invalidate()
	end
end

function AtlasSpecClass:ResetNodes()
	self:ApplyState(self.treeVersion, { }, { })
end

function AtlasSpecClass:CountAllocNodes()
	return #self:GetAllocatedIds()
end

function AtlasSpecClass:SetVariant(nodeId, effect)
	local node = self.allocNodes[nodeId]
	if not node or not node.variants then
		return false
	end
	for _, variant in ipairs(node.variants) do
		if variant.effect == effect then
			self.variantSelections[nodeId] = effect
			self:Invalidate()
			return true
		end
	end
	return false
end

function AtlasSpecClass:GetSelectedVariant(node)
	local effect = self.variantSelections[node.id]
	for _, variant in ipairs(node.variants or { }) do
		if variant.effect == effect then
			return variant
		end
	end
end

function AtlasSpecClass:SetTreeVersion(key)
	return self:ApplyState(key, self:GetAllocatedIds(), self.variantSelections)
end

function AtlasSpecClass:CreateUndoState()
	local variants = { }
	for nodeId, effect in pairs(self.variantSelections) do
		variants[nodeId] = effect
	end
	return { treeVersion = self.treeVersion, nodes = self:GetAllocatedIds(), variants = variants, title = self.title }
end

function AtlasSpecClass:RestoreUndoState(state)
	self.title = state.title
	self:ApplyState(state.treeVersion, state.nodes, state.variants)
end

function AtlasSpecClass:Load(xml)
	self.title = xml.attrib.title or "Default"
	local ids = { }
	for id in (xml.attrib.nodes or ""):gmatch("%d+") do
		t_insert(ids, tonumber(id))
	end
	local variants = { }
	for _, child in ipairs(xml) do
		if type(child) == "table" and child.elem == "Variant" then
			local nodeId, effect = tonumber(child.attrib.nodeId), tonumber(child.attrib.effect)
			if nodeId and effect then
				variants[nodeId] = effect
			end
		end
	end
	self:ApplyState(xml.attrib.treeVersion, ids, variants)
	self:ResetUndo()
	self.modFlag = false
end

function AtlasSpecClass:Save(xml)
	local ids = { }
	for _, id in ipairs(self:GetAllocatedIds()) do
		t_insert(ids, tostring(id))
	end
	xml.attrib = {
		title = self.title,
		treeVersion = self.treeVersion,
		nodes = t_concat(ids, ","),
	}
	local variantIds = { }
	for nodeId in pairs(self.variantSelections) do
		t_insert(variantIds, nodeId)
	end
	t_sort(variantIds)
	for _, nodeId in ipairs(variantIds) do
		t_insert(xml, { elem = "Variant", attrib = { nodeId = tostring(nodeId), effect = tostring(self.variantSelections[nodeId]) } })
	end
end
