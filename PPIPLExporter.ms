-- Helper: format float with 3 decimals
fn floatToStr3 num = (formattedPrint num format:"0.3f")

-- Helper: format float with 4 decimals
fn floatToStr4 num = (formattedPrint num format:"0.4f")

-- Helper: trims whitespace from both ends of a string
fn trim str = (
    if str == undefined or str == "" then return ""
    local whitespace = "\t\n\r "
    local start = 1
    local endIdx = str.count
    while (start <= endIdx and findString whitespace (substring str start 1) != undefined) do start += 1
    while (endIdx >= start and findString whitespace (substring str endIdx 1) != undefined) do endIdx -= 1
    if start > endIdx then "" else substring str start (endIdx - start + 1)
)

-- Helper: round a Point3 to 3 decimals
fn roundPosTo3 p = (
    point3 
        (ceil (p.x * 1000) / 1000.0)
        (ceil (p.y * 1000) / 1000.0)
        (ceil (p.z * 1000) / 1000.0)
    
)

-- Helper: round quaternion to 4 decimals
fn roundQuat q = (
    quat 
        (ceil (q.x * 10000) / 10000.0)
        (ceil (q.y * 10000) / 10000.0)
        (ceil (q.z * 10000) / 10000.0)
        (ceil (q.w * 10000) / 10000.0)
 )

-- Helper: compare two quaternions rounded to 4 decimals
fn isEqual q1 q2 = (
    roundQuat q1 == roundQuat q2
)

-- Convert quaternion to GTA format with 4 decimal rounding
fn quatToGTAFormat quat = (
    local x = quat.x
    local y = quat.y
    local z = -quat.z
    local w = quat.w

    if x >= 0 and y >= 0 then (
        x = -x
        y = -y
    )

    x = (ceil (x * 10000)) / 10000.0
    y = (ceil (y * 10000)) / 10000.0
    z = (ceil (z * 10000)) / 10000.0
    w = (ceil (w * 10000)) / 10000.0

    return #(x, y, z, w)
)

-- Struct for IDE name-to-ID mapping and matching
struct IDEnumToolStruct (
    idMap = #(),
    idNamesLower = #(),
    cancelFlag = false,

    function clearData = (
        idMap = #()
        idNamesLower = #()
    ),

    function loadDataFromFilesWithProgress fileList progressBar progressLabel = (
        clearListener()
        cancelFlag = false
        this.clearData()
        local totalFiles = fileList.count
        local currentFile = 0

        for file in fileList do (
            if cancelFlag then return false
            currentFile += 1

            local fileStream = openFile file mode:"r"
            if fileStream == undefined then (
                format "Failed to open file: %\n" file
                continue
            )

            try (
                while not eof fileStream and not cancelFlag do (
                    local rawLine = readline fileStream
                    local line = trim rawLine
                    if line == "" or matchPattern line pattern:";*" then continue
                    local values = filterString line ","
                    if values.count < 2 then continue

                    local objectID = trim values[1]
                    local objectName = trim values[2]
                    local objectNameLower = toLower objectName

                    if objectID != "" and objectName != "" and (findItem idNamesLower objectNameLower) == 0 then (
                        append idMap #(objectName, objectID)
                        append idNamesLower objectNameLower
                    )
                )
            ) catch (
                format "Error processing file: %\n" file
            )
            close fileStream

            if progressBar != undefined and progressLabel != undefined then (
                progressBar.value = (100.0 * currentFile / totalFiles)
                progressLabel.text = "Processed " + currentFile as string + " / " + totalFiles as string
                windows.processPostedMessages()
            )
        )

        if progressBar != undefined and progressLabel != undefined then (
            progressBar.value = 100
            progressLabel.text = "Processed " + totalFiles as string + " / " + totalFiles as string
            windows.processPostedMessages()
        )

        not cancelFlag
    ),

    function findMatchesInSelection = (
        local matches = #()
        local unmatched = #()
        for obj in selection do (
            local objNameClean = toLower (trim obj.name)
            local idx = findItem idNamesLower objNameClean
            if idx > 0 then (
                local pair = idMap[idx]
                local pos = obj.position
                local quat = quatToGTAFormat obj.rotation
                append matches #(obj.name, pair[2], pos, quat)
            ) else (
                append unmatched obj.name
            )
        )
        return #(matches, unmatched)
    )
)

-- Global tool instance
global IDEnumTool = IDEnumToolStruct()
IDEnumTool.clearData()

-- Rollout UI
rollout IDEnumRollout "Project Props IPL Exporter - Zen (No LOD)" width:600 height:570 (
    local ideFileList = #()
    local matchedObjs = #()
    local uniqueMatches = #()
    local unmatchedObjs = #()
    local rolloutWidth = 600

    fn centerX ctrlWidth = (rolloutWidth - ctrlWidth) / 2

    groupBox grp_file "Added .IDE Files" pos:[centerX 360,10] width:360 height:110
    listbox lb_files "" pos:[centerX 340,30] width:340 height:4
    button btn_addFile "Add .IDE File..." pos:[centerX 170 - 90,90] width:170
    button btn_clearFiles "Clear .IDE Files" pos:[centerX 170 + 90,90] width:170

    button btn_load "Scan Selections" pos:[centerX 170 - 90,130] width:170 height:30
    button btn_cancel "Cancel" pos:[centerX 170 + 90,130] width:170 height:30 enabled:false

    label lbl_status "No files loaded." pos:[centerX 360,170] width:360
    progressbar pb_progress "" pos:[centerX 360,200] width:360 height:16
    label lbl_progressCount "" pos:[centerX 360,222] width:360

    groupBox grp_matches "Matched Objects" pos:[centerX 560,250] width:560 height:130
    listbox lb_matches "" pos:[centerX 540,270] width:540 height:9 multiSelection:true
    on lb_matches.selected selectedIndices do (
        local indices = if classof selectedIndices == Integer then #(selectedIndices) else selectedIndices
        local nodesToSelect = #()
        for idx in indices do (
            if idx > 0 and idx <= matchedObjs.count then (
                local match = matchedObjs[idx]
                local matchPos = roundPosTo3 match[3]
                local matchQuat = match[4]
                for node in objects do (
                    if roundPosTo3 node.position == matchPos and isEqual (quatToGTAFormat node.rotation) matchQuat do (
                        append nodesToSelect node
                    )
                )
            )
        )
        if nodesToSelect.count > 0 then select nodesToSelect
    )

    groupBox grp_unmatched "Unmatched Objects" pos:[centerX 560,400] width:560 height:100
    listbox lb_unmatched "" pos:[centerX 540,420] width:540 height:6 multiSelection:true
    on lb_unmatched selected selectedIndices do (
        local indices = if classof selectedIndices == Integer then #(selectedIndices) else selectedIndices
        local nodesToSelect = #()
        for idx in indices do (
            local name = lb_unmatched.items[idx]
            for node in objects where trim node.name == name do append nodesToSelect node
        )
        if nodesToSelect.count > 0 then select nodesToSelect
    )

    button btn_clearMatches "Clear Matches" pos:[centerX 170 - 90,530] width:170 height:30
    button btn_exportScene "Export Selected to IPL" pos:[centerX 170 + 90,530] width:170 height:30

    on btn_addFile pressed do (
        local newFile = getOpenFileName caption:"Select .IDE File" types:"IDE Files (*.ide)|*.ide|All Files (*.*)|*.*|"
        if newFile != undefined and findItem ideFileList newFile == 0 then (
            append ideFileList newFile
            lb_files.items = ideFileList
            lbl_status.text = (ideFileList.count as string) + " files loaded."
        )
    )

    on btn_clearFiles pressed do (
        ideFileList = #()
        lb_files.items = #()
        lbl_status.text = "Files list cleared."
    )

    on btn_clearMatches pressed do (
        uniqueMatches = #()
        lb_matches.items = #()
        unmatchedObjs = #()
        lb_unmatched.items = #()
        lbl_status.text = "Matches list cleared."
    )

    on btn_cancel pressed do (
        IDEnumTool.cancelFlag = true
        lbl_progressCount.text = "Cancelling..."
        btn_cancel.enabled = false
    )

    on btn_load pressed do (
        if ideFileList.count == 0 then (
            messageBox "Please add at least one .IDE file." title:"No Files"
            return()
        )

        pb_progress.value = 0
        lbl_progressCount.text = ""
        btn_cancel.enabled = true

        local tempResultStrings = #()
        local loadSuccess = IDEnumTool.loadDataFromFilesWithProgress ideFileList pb_progress lbl_progressCount

        if IDEnumTool.cancelFlag or not loadSuccess then (
            IDEnumTool.clearData()
            lbl_status.text = "Load cancelled."
            pb_progress.value = 0
            btn_cancel.enabled = false
            return()
        )

        local matchResults = IDEnumTool.findMatchesInSelection()
        local tempMatches = matchResults[1]
        local tempUnmatched = matchResults[2]

        for pair in tempMatches do (
            local pos = pair[3]
            local quat = pair[4]
            local matchString = pair[2] + ", " + pair[1] + ", 512, " +
                floatToStr3 pos.x + ", " + floatToStr3 pos.y + ", " + floatToStr3 pos.z + ", " +
                floatToStr4 quat[1] + ", " + floatToStr4 quat[2] + ", " + floatToStr4 quat[3] + ", " + floatToStr4 quat[4] + ", -1"
            append tempResultStrings matchString
        )

        lb_unmatched.items = tempUnmatched

        if not IDEnumTool.cancelFlag and loadSuccess then (
            matchedObjs = tempMatches
            uniqueMatches = tempResultStrings
            sort uniqueMatches
            lb_matches.items = uniqueMatches
            lbl_status.text = matchedObjs.count as string + " matches found."
        )

        pb_progress.value = 100
        lbl_progressCount.text = "Load complete."
        btn_cancel.enabled = false
    )

    on btn_exportScene pressed do (
        if selection.count == 0 then (
            messageBox "No objects selected to export." title:"Export Error"
            return()
        )

        local saveFile = getSaveFileName caption:"Save IPL File As" types:"IPL Files (*.ipl)|*.ipl|All Files (*.*)|*.*|"
        if saveFile == undefined then return()

        local mainEntries = #()

        for obj in selection do (
            local objName = trim obj.name
            local objNameLower = toLower objName
            local idx = findItem IDEnumTool.idNamesLower objNameLower
            if idx > 0 then (
                local pair = IDEnumTool.idMap[idx]
                local id = pair[2]
                local pos = obj.position
                local quat = quatToGTAFormat obj.rotation

                local line = id + ", " + obj.name + ", 512, " +
                    floatToStr3 pos.x + ", " + floatToStr3 pos.y + ", " + floatToStr3 pos.z + ", " +
                    floatToStr4 quat[1] + ", " + floatToStr4 quat[2] + ", " + floatToStr4 quat[3] + ", " + floatToStr4 quat[4] + ", -1"
                append mainEntries line
            )
        )

        fn writeIPLFile filename lines = (
            local stream = createFile filename
            if stream != undefined then (
                format "inst\n" to:stream
                for line in lines do format "%\n" line to:stream
                format "end\n" to:stream
                close stream
            )
        )

        writeIPLFile saveFile mainEntries

        messageBox (
            "Exported:\nIPL: " + mainEntries.count as string + " entries\n\nSaved to:\n" + saveFile
        ) title:"Export Complete"
    )
)

createDialog IDEnumRollout
