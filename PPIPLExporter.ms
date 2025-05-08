fn floatToStr6 num =
(
    formattedPrint num format:"0.6f"
)

function trim str =
(
    if str == undefined or str == "" then return ""
    local whitespace = "\t\n\r "
    local start = 1
    local endIdx = str.count

    while (start <= endIdx and findString whitespace (substring str start 1) != undefined) do start += 1
    while (endIdx >= start and findString whitespace (substring str endIdx 1) != undefined) do endIdx -= 1

    if start > endIdx then "" else substring str start (endIdx - start + 1)
)

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
            if cancelFlag do return false
            currentFile += 1

            if (fileStream = openFile file mode:"r") == undefined do (
                format "Failed to open file: %\n" file
                continue
            )

            try (
                while not eof fileStream and not cancelFlag do (
                    local rawLine = readline fileStream
                    local line = trim rawLine
                    if line == "" or matchPattern line pattern:";*" do continue

                    local values = filterString line ","
                    if values.count < 2 do continue

                    local objectID = trim values[1]
                    local objectName = trim values[2]
                    local objectNameLower = toLower objectName

                    if objectID != "" and objectName != "" and (findItem idNamesLower objectNameLower) == 0 do (
                        append idMap #(objectName, objectID)
                        append idNamesLower objectNameLower
                    )
                )
            ) catch (
                format "Error processing file: %\n" file
            )
            close fileStream

            if progressBar != undefined and progressLabel != undefined do (
                progressBar.value = (100.0 * currentFile / totalFiles)
                progressLabel.text = "Processed " + currentFile as string + " / " + totalFiles as string
                windows.processPostedMessages()
            )
        )

        if progressBar != undefined and progressLabel != undefined do (
            progressBar.value = 100
            progressLabel.text = "Processed " + totalFiles as string + " / " + totalFiles as string
            windows.processPostedMessages()
        )

        not cancelFlag
    ),

    function findMatchesInSelection = (
        local matches = #()
        for obj in selection do (
            local objNameClean = toLower (trim obj.name)
            local idx = findItem idNamesLower objNameClean
            if idx > 0 do (
                local pair = idMap[idx]
                local pos = obj.position
                local rot = obj.rotation as quat
                append matches #(obj.name, pair[2], pos, rot)
            )
        )
        matches
    )
)

global IDEnumTool = IDEnumToolStruct()
IDEnumTool.clearData()

rollout IDEnumRollout "Project Props IPL Exporter - Zen" width:360 height:480 (
    local ideFileList = #()
    local matchedObjs = #()
    local uniqueMatches = #()

    groupBox grp_file "Added .IDE Files" pos:[10,10] width:340 height:100
    listbox lb_files "" pos:[20,30] width:320 height:4
    button btn_addFile "Add .IDE File..." pos:[20,95] width:150
    button btn_clearFiles "Clear .IDE files from list" pos:[190,95] width:150

    button btn_load "Scan Selections" pos:[20,120] width:150 height:30
    button btn_cancel "Cancel" pos:[190,120] width:150 height:30 enabled:false

    label lbl_status "No files loaded." pos:[20,160] width:320
    progressbar pb_progress "Progress" pos:[20,190] width:320 height:16
    label lbl_progressCount "" pos:[20,210] width:320

    label lbl_matches "Matches:" pos:[20,230] width:320
    listbox lb_matches "" pos:[20,250] width:320 height:10

    button btn_clearMatches "Clear Matches" pos:[20,420] width:150 height:30
    button btn_exportScene "Export Selected to IPL" pos:[190,420] width:160 height:30

    on btn_addFile pressed do (
        local newFile = getOpenFileName caption:"Select .IDE File" types:"IDE Files (*.ide)|*.ide|All Files (*.*)|*.*|"
        if newFile != undefined and findItem ideFileList newFile == 0 do (
            append ideFileList newFile
            lb_files.items = ideFileList
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
        lbl_status.text = "Matches list cleared."
    )

    on btn_cancel pressed do (
        IDEnumTool.cancelFlag = true
        lbl_progressCount.text = "Cancelling..."
        btn_cancel.enabled = false
    )

    on btn_load pressed do (
        if ideFileList.count == 0 do (
            messageBox "Please add at least one .IDE file." title:"No Files"
            return()
        )

        pb_progress.value = 0
        lbl_progressCount.text = ""
        btn_cancel.enabled = true

        -- Don't clear matches list until we know it's a successful scan
        local tempMatches = #()
        local tempResultStrings = #()

        local loadSuccess = IDEnumTool.loadDataFromFilesWithProgress ideFileList pb_progress lbl_progressCount

        if IDEnumTool.cancelFlag or not loadSuccess do (
            IDEnumTool.clearData()
            lbl_status.text = "Load cancelled."
            pb_progress.value = 0
            btn_cancel.enabled = false
            return()
        )

        tempMatches = IDEnumTool.findMatchesInSelection()
        for pair in tempMatches do (
            local pos = pair[3]
            local rot = pair[4]

            local matchString = pair[2] + ", " + pair[1] + ", 512, " +
                floatToStr6 pos.x + ", " + floatToStr6 pos.y + ", " + floatToStr6 pos.z + ", " +
                floatToStr6 rot.x + ", " + floatToStr6 rot.y + ", " + floatToStr6 rot.z + ", " +
                floatToStr6 rot.w + ", -1"
            append tempResultStrings matchString
        )

        if not IDEnumTool.cancelFlag and loadSuccess do (
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
        if selection.count == 0 do (
            messageBox "No objects selected to export." title:"Export Error"
            return()
        )

        local saveFile = getSaveFileName caption:"Export Selected Objects to .ipl" types:"IPL Files (*.ipl)|*.ipl|All Files (*.*)|*.*|"
        if saveFile == undefined do return()

        local exportLines = #("inst")
        for obj in selection do (
            local objNameLower = toLower (trim obj.name)
            local idx = findItem IDEnumTool.idNamesLower objNameLower
            local matchedID = undefined

            if idx > 0 do (
                local pair = IDEnumTool.idMap[idx]
                matchedID = pair[2]
            )

            if matchedID == undefined do continue

            local pos = obj.position
            local rot = obj.rotation as quat

            local line = matchedID + ", " + obj.name + ", 512, " +
                floatToStr6 pos.x + ", " + floatToStr6 pos.y + ", " + floatToStr6 pos.z + ", " +
                floatToStr6 rot.x + ", " + floatToStr6 rot.y + ", " + floatToStr6 rot.z + ", " +
                floatToStr6 rot.w + ", -1"
            append exportLines line
        )

        append exportLines "end"

        local fileStream = createFile saveFile
        if fileStream == undefined do (
            messageBox "Failed to create file." title:"Error"
            return()
        )

        for line in exportLines do format "%\n" line to:fileStream
        close fileStream

        messageBox ("Exported " + (exportLines.count - 2) as string + " entries to:\n" + saveFile) title:"Export Complete"
    )
)

createDialog IDEnumRollout
