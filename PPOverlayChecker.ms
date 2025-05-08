(
    /*------------------------
      Helper Functions
    ------------------------*/
    fn getBoundingBox obj =
    (
        local tm = obj.objecttransform
        local bb
        try
            bb = nodeGetBoundingBox obj tm
        catch
            return undefined
        #(bb[1] * tm, bb[2] * tm)
    )

    fn getObjectCenterFromBBox bb =
        if bb != undefined then (bb[1] + bb[2]) / 2.0 else [0,0,0]

    fn getPivotPosition obj =
    (
        if isValidNode obj then
            return (obj.position + obj.pivot)
        else
            return undefined
    )

    fn isValidObject obj = isValidNode obj and isProperty obj #objecttransform

    fn getVertCount obj =
    (
        if isValidNode obj and isProperty obj #mesh and isProperty obj.mesh #numverts then
        (
            try (obj.mesh.numverts) catch(0)
        )
        else 0
    )

    fn objectsOverlapCheck bbox1 bbox2 tolerance =
    (
        (bbox1[1].x <= bbox2[2].x + tolerance and bbox2[1].x <= bbox1[2].x + tolerance) and
        (bbox1[1].y <= bbox2[2].y + tolerance and bbox2[1].y <= bbox1[2].y + tolerance) and
        (bbox1[1].z <= bbox2[2].z + tolerance and bbox2[1].z <= bbox1[2].z + tolerance)
    )

    fn areNearDuplicates obj1 obj2 overlapTolerance pivotThreshold =
    (
        if toLower obj1.name != toLower obj2.name then return false

        local piv1 = getPivotPosition obj1
        local piv2 = getPivotPosition obj2
        if piv1 == undefined or piv2 == undefined then return false

        local pivDist = distance piv1 piv2
        if pivDist > pivotThreshold then return false

        if not objectsOverlapCheck (getBoundingBox obj1) (getBoundingBox obj2) overlapTolerance then return false

        return true
    )

    fn areVertexCountsSimilar obj1 obj2 =
    (
        getVertCount obj1 == getVertCount obj2
    )

    fn highlightObjects objs =
    (
        for o in objs do
        (
            try o.wirecolor = color 0 255 255 catch()
        )
    )

    fn checkAndReportOverlappingObjects overlapTolerance pivotThreshold =
    (
        undo "Check Overlapping Duplicates" on
        (
            local baseSet = if selection.count == 0 then (for obj in geometry where isValidObject obj and not obj.isFrozen collect obj) else selection
            local allObjects = for obj in baseSet where isValidObject obj collect obj

            local bboxCache = for obj in allObjects collect
            (
                local bb = getBoundingBox obj
                if bb != undefined then #(obj, bb, getObjectCenterFromBBox bb) else undefined
            )
            bboxCache = for b in bboxCache where b != undefined collect b

            local groups = #()
            local visited = #()

            disableSceneRedraw()
            progressStart "Checking for Overlapping Duplicates..."

            try
            (
                for i = 1 to bboxCache.count do
                (
                    if findItem visited bboxCache[i][1] > 0 do continue

                    local obj1 = bboxCache[i][1]
                    local bbox1 = bboxCache[i][2]
                    local group = #(obj1)
                    append visited obj1

                    for j = i + 1 to bboxCache.count do
                    (
                        local obj2 = bboxCache[j][1]
                        if findItem visited obj2 > 0 do continue

                        local bbox2 = bboxCache[j][2]

                        if areNearDuplicates obj1 obj2 overlapTolerance pivotThreshold and areVertexCountsSimilar obj1 obj2 then
                        (
                            append group obj2
                            append visited obj2
                        )
                    )

                    if group.count > 1 do append groups group
                )
            )
            catch
            (
                messageBox ("Error during check:\n" + (getCurrentException() as string))
            )

            progressEnd()
            enableSceneRedraw()

            local finalSelection = #()
            for g in groups do
            (
                for k = 2 to g.count do append finalSelection g[k]
            )

            finalSelection = makeUniqueArray finalSelection
            select finalSelection
            highlightObjects finalSelection

            if finalSelection.count == 0 then
                messageBox "No identical overlapping objects found."
            else
                messageBox ("Selected " + finalSelection.count as string + " overlapping duplicates (keeping 1 per group).")
        )
    )

    /*------------------------
      UI Definition
    ------------------------*/
    rollout overlapCheckerUI "Project Props Overlap Checker - Zen" width:420 height:140
    (
        groupBox grpTolerance "Tolerance Settings" pos:[10,10] width:400 height:80

        spinner toleranceSpinner "Bounding Box Overlap Tolerance (m):" pos:[30,30] width:360 range:[0,40,0] type:#float scale:0.1
        spinner pivotThresholdSpinner "Pivot Match Distance (m):" pos:[30,55] width:360 range:[0,40,0] type:#float scale:0.1

        button checkOverlapButton "Run Overlap Check" pos:[30,100] width:360 height:28 tooltip:"Scans entire scene when no objects are selected. Ignores frozen objects."

        on checkOverlapButton pressed do
        (
            local overlapTol = toleranceSpinner.value
            local pivotThresh = pivotThresholdSpinner.value

            checkAndReportOverlappingObjects overlapTol pivotThresh
        )
    )
    createDialog overlapCheckerUI
)
