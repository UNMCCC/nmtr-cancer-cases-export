Overview
--------

By State law, cancer is a reportable disease, and we ought to notify the state
about the cancer cases the UNMCCC sees each month.

We need to procure lists of new cases to the state registry in a monthly basis.
The process described here accomplish the state law reporting requirements. We
implemented a sequence of automated actions: We trigger a Mosaiq Database SQL
query using a once a windows scheduler monthly task. The query results in a
comma-delimited file with a list of cancer cases. Then we trigger a secure file
transfer that places the resulting comma-delimited file in the NM Tumor
Registry.

### What UNMCCC DOES NOW

![](media/b7280fbb761f00b3d2ac577f7579e662.png)

Automation process
------------------

We need to report each third-Monday of the month day the UNMCCC cancer cases, in
a comma-delimited file and send the file over to NMTR using their secure ftp
server.

### For developers/informatics/Sysadmins only

This automated process combines batch (DOS) scripts that invoke the utilities
“sqlcmd” and “winscp”, along with system utilities (file copy, redirect). These
executables are on a timetable run by the Windows Task Scheduler.

The *sqlcmd* executes a monthly NMTR script named *nmtr\_export.sql*

The output file conforms to the NMTR requirements, and the filename contains
dates of the month.

The **sql** scripts and **bat** files are located in the Mosaiq application
server under the **C:\\NMTR** folder.

The output files are in a local share of the Mosaiq application server
(\\\\.....\\EXPORT\\NMTR).

A batch process (controlled by a bat. File) uploads data invoking the command
line for WinSCP, at the mosaiq outbound interface server.

BAT files with the batch scripts are in the C:\\IQ Export folder, and called
IQExport.bat. The IQExport.bat file contains this sole instruction:

sqlcmd -U Username -P=password -S MOSAICDATABASE -i C:\\IQ\\nmtr\_export.sql
-s";" -W -h-1 -o
\\\\SERVERPATH\\app2\\MOSAIQ\_App\\EXPORT\\NMTR\\Upload\\UNM\_NMTR\_%date:\~-4,4%\_%date:\~-10,2%.txt

![](media/7b0a4f816d02b267b73653c2cf292e32.png)

The NMTRUploadAndMove task starts the WinSCP is on the Mosaiq Outbound interface
server ignites a bat file in C:\\NMTRScripts encoding the WinSCP file transfer

![](media/84a8d0e7c8621752f395ed5a773d36ac.png)

