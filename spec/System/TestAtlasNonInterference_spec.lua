describe("Atlas non-interference", function()
	local function snapshot()
		local values = { }
		for key, value in pairs(build.calcsTab.mainOutput) do
			if type(value) == "number" then
				values[key] = value
			end
		end
		return values
	end

	local atlasSection = '<Atlas activeSpec="2"><Spec title="A" treeVersion="3_30" nodes="63753,57123"/><Spec title="B" treeVersion="3_30" nodes="45404"><Variant nodeId="45404" effect="55878"/></Spec><Spec title="C" treeVersion="3_25" nodes=""/></Atlas>'

	for _, name in ipairs({ "Dual Savior", "Dual Wield Cospris CoC", "Generals Perforate Zerker" }) do
		it("keeps calc output identical for " .. name, function()
			local testBuild = LoadModule("../spec/TestBuilds/3.13/" .. name .. ".lua")
			loadBuildFromXML(testBuild.xml, name)
			local before = snapshot()
			loadBuildFromXML(testBuild.xml:gsub("</PathOfBuilding>", atlasSection .. "</PathOfBuilding>"), name)
			assert.are.equal(3, #build.atlasTab.specList)
			assert.are.same(before, snapshot())
			build.buildFlag = false
			build.atlasTab:HandleNodeClick(build.atlasTab.spec.tree.nodes[3204])
			runCallback("OnFrame")
			assert.is_false(build.buildFlag)
			assert.are.same(before, snapshot())
		end)
	end
end)
