<#
Example Old Diretory
    Ab 2020
        Alpha 2020
            Alpha1.0 2020
                AlphaMicro 2020
New Directory
    Ab 2021
        Alpha 2021
            Alpha1.0 2021
                AlphaMicro 2021
#>

#Copies original directory structure and excludes the files
robocopy 'C:\Test 2020' 'C:\Test 2021' /COPYALL /e /ETA /PF /zb /R:1 /W:1 /mt /xf *.*

#Gets all folders in the new directory and replaces '2020' with '2021' 
Get-ChildItem -Path 'C:\Test 2021' -Recurse |Rename-Item -NewName {$_.name -replace '2020','2021'} -Verbose 