Overview
--------

By State law, cancer is a reportable disease. The UNM Cancer Center must notify the state about any new cancer cases the UNMCCC sees each month. The reporting includes any cases seen at any of the UNM medical facilities, including but not limited to the Comprehensive Cancer Center.

We procure lists of new cases to the New Mexico state registry in a monthly basis. The process described here facilitates the state law reporting requirement. What we do is collect the new cases from the two electronic medical record (EMR) systems, merge the lists, deduplicate the new cases, and export them in HL7 format. That's is the extent of what is described here, but note that the HL7 ADT A08 feeds are then scrubbed by the CAS listener, part of the CNExT casefinding software.  CNExT is used by the local registry experts at the UNMCCC to curate, abstract and translate the typical billing codes provided by the UNM Cerner and Mosaiq EMRs into actual medical diagnoses.

We implemented a sequence of automated actions: We trigger a Mosaiq Database SQL query using a once a windows scheduler monthly task. The query results in a comma-delimited file with a list of cancer cases. Then we trigger a secure file transfer that places the resulting comma-delimited file in the NM Tumor Registry. We also retrieve the UNMH comma delimited data file feed, and run both files through a Perl script that deduplicates, curates and transforms the format into HL7 ADT A08 format.

### What UNMCCC DOES NOW

![image](https://cloud.githubusercontent.com/assets/403087/24419093/4a7ad856-13ab-11e7-9b35-2c09a174ab43.png)

Automation process
------------------

We need to report each third-Monday of the month day the UNMCCC cancer cases, in a comma-delimited file and send the file over to NMTR using their secure ftp server.

### For developers/informatics/Sysadmins only

This automated process combines batch (DOS) scripts that invoke the utilities “sqlcmd” and “winscp”, along with system utilities (file copy, redirect). These executables are on a timetable run by the Windows Task Scheduler.

The *sqlcmd* executes a monthly NMTR script named *nmtr\_export.sql*

The output file conforms to the NMTR requirements, and the filename contains dates of the month.

The **sql** scripts and **bat** files are located in the Mosaiq application server under the **C:\\NMTR** folder.

The output files are in a local share of the Mosaiq application server
(\\\\.....\\EXPORT\\NMTR).

A batch process (controlled by a bat. File) uploads data invoking the command line for WinSCP, at the mosaiq outbound interface server.

BAT files with the batch scripts are in the C:\\NMTR Export folder, and called NMTRExport.bat. The NMTRExport.bat file contains this sole instruction:

sqlcmd -U Username -P=password -S MOSAICDATABASE -i C:\\IQ\\nmtr\_export.sql -s";" -W -h-1 -o
\\\\SERVERPATH\\app2\\MOSAIQ\_App\\EXPORT\\NMTR\\Upload\\UNM\_NMTR\_%date:\~-4,4%\_%date:\~-10,2%.txt

![image](https://cloud.githubusercontent.com/assets/403087/24419110/577ad66e-13ab-11e7-9ffc-d78f1075f28b.png)

The NMTRUploadAndMove task starts the WinSCP is on the Mosaiq Outbound interfaceserver ignites a bat file in C:\\NMTRScripts encoding the WinSCP file transfer

![image](https://cloud.githubusercontent.com/assets/403087/24421530/ba9fa596-13b3-11e7-849c-5cc07255a054.png)

