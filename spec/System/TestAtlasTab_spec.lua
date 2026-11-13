describe("AtlasTab", function()
	before_each(function()
		newBuild()
	end)

	it("hooks into the build without triggering calculations", function()
		local tab = build.atlasTab
		assert.are.equal(latestAtlasTreeVersion, tab.spec.treeVersion)
		build.controls.modeAtlas.onClick()
		assert.are.equal("ATLAS", build.viewMode)
		runCallback("OnFrame")
		build.buildFlag = false
		tab:HandleNodeClick(tab.spec.tree.nodes[63753])
		assert.are.equal(12, tab.spec:CountAllocNodes())
		assert.is_true(tab:IsModified())
		runCallback("OnFrame")
		assert.is_true(build.unsaved)
		assert.is_false(build.buildFlag)
		tab:HandleNodeClick(tab.spec.tree.nodes[57123])
		assert.are.equal(10, tab.spec:CountAllocNodes())
		tab:HandleNodeClick(tab.spec.tree.nodes[45404])
		assert.is_not_nil(main.popups[1])
		main.popups[1].controls.variant.selFunc(2)
		assert.are.equal(5301, tab.spec.variantSelections[45404])
		main:ClosePopup()
		tab:ClearActiveSpec()
		assert.are.equal(0, tab.spec:CountAllocNodes())
		tab.spec:Undo()
		assert.is_true(tab.spec:CountAllocNodes() > 0)
	end)

	it("saves and loads atlas trees with the build", function()
		local tab = build.atlasTab
		tab.spec:AllocNode(tab.spec.tree.nodes[63753])
		local second = tab:NewSpec("Breach farming")
		second:AllocNode(second.tree.nodes[45404])
		second:SetVariant(45404, 55878)
		build.viewMode = "ATLAS"
		local xml = build:SaveDB("code")
		assert.is_truthy(xml:find('viewMode="TREE"', 1, true))
		loadBuildFromXML(xml)
		tab = build.atlasTab
		assert.are.equal(2, #tab.specList)
		assert.are.equal("Breach farming", tab.specList[2].title)
		assert.are.equal(12, tab.specList[1]:CountAllocNodes())
		assert.are.equal(55878, tab.specList[2].variantSelections[45404])
		assert.are.equal(2, tab.activeSpec)
	end)

	it("tolerates unknown atlas versions", function()
		local xml = build:SaveDB("code"):gsub("<Atlas[^>]*>.-</Atlas>", '<Atlas activeSpec="1"><Spec title="X" treeVersion="9_99" nodes="57123"/></Atlas>')
		wipeTable(main.popups)
		loadBuildFromXML(xml)
		assert.are.equal(latestAtlasTreeVersion, build.atlasTab.spec.treeVersion)
		for _, popup in ipairs(main.popups) do
			assert.are_not.equal("Unknown Passive Tree Version", popup.title)
		end
	end)

	it("round-trips share links", function()
		local spec = build.atlasTab.spec
		spec:AllocNode(spec.tree.nodes[45404])
		spec:SetVariant(45404, 5301)
		local link = spec:EncodeURL()
		assert.is_truthy(link:find("^https://www.pathofexile.com/fullscreen%-atlas%-skill%-tree/AAAABgAA"))
		local other = new("AtlasSpec"):AtlasSpec(spec.treeVersion)
		assert.is_true(other:DecodeURL(link))
		assert.are.same(spec:GetAllocatedIds(), other:GetAllocatedIds())
		assert.are.equal(5301, other.variantSelections[45404])
		local bare = new("AtlasSpec"):AtlasSpec(spec.treeVersion)
		assert.is_true(bare:DecodeURL(link:match("[^/]+$")))
		assert.is_false((other:DecodeURL("garbage")))
		assert.are.same(spec:GetAllocatedIds(), other:GetAllocatedIds())
	end)

	it("summarises stats", function()
		local spec = build.atlasTab.spec
		spec:AllocNode(spec.tree.nodes[55117])
		spec:AllocNode(spec.tree.nodes[64048])
		local found = 0
		for _, category in ipairs(spec:GetStatSummary()) do
			for _, line in ipairs(category.lines) do
				if line.text == "4% increased Maps found in your Maps" then
					found = found + 1
					assert.are.equal(2, #line.nodes)
				end
			end
		end
		assert.are.equal(1, found)
		spec:AllocNode(spec.tree.nodes[3204])
		local breach = false
		for _, category in ipairs(spec:GetStatSummary()) do
			for _, line in ipairs(category.lines) do
				assert.is_nil(line.text:find("[", 1, true))
				if category.category == "Breach" and line.text:find("^Unstable Breaches in your Maps are 10%% faster") then
					breach = true
				end
			end
		end
		assert.is_true(breach)
	end)
end)
