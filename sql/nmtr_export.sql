/*1.23.15 - KB modified since we are not closing ledger after CLS_ID = 80 (Nov2014); update the whole query to point to Charge table (confirmed w/JP)*/
/*KB modified 8/29/12 to take out trx_amt and modified Aclose.CLS_ID to prior month
KB modified 4-26-12 for 2.3 Upgrade (ICD9 fields had to be linked, etc.)
ISG Jan-24-2018.  Changed to remove actual CPTs, which are not usable by NMTR.  Stop at distinct MRN-DOS-DX, reduces the list.4*/

declare @TodayMonthAgo as Date = dateadd(month,-1,GetDate())
declare @StartOfMonth as Date = DateAdd( day, 1 - Day( @TodayMonthAgo ), @TodayMonthAgo )
declare @EndOfMonth as Date = DateAdd( day, -1, DateAdd( month, 1, @StartOfMonth ) )

Set nocount on

SELECT distinct     
 Ident.IDA AS MRN, 
 Patient.First_Name AS FirstName, 
 Patient.MIddle_Name AS MiddleName, 
 Patient.Last_Name AS LastName, 
 Admin.Gender AS Sex, 
 Admin.Race, 
 Admin.Pat_Adr1 AS StreetAddress, 
 Admin.Pat_City AS City,  
 Admin.Pat_State AS State, 
 Admin.Pat_Postal AS Zip, 
 replace(patient.SS_Number,'-','') AS SSN,
 Convert(char(10),Patient.Birth_DtTm,112) AS DOB, 
 Ident.IDC AS DOD, 
 Convert(char(10),Admin.Expired_DtTm,112) AS Expired_DtTm,
 Convert(char(10),CHG.Proc_DtTm,112) AS DOS,
 dbo.fn_FormatName(Staff.Last_Name, Staff.First_Name, Staff.Mdl_Initial, 'NAMEFML', 'STAFF') AS Physician, 
 RTRIM (ISNULL(T1.Diag_code,'')) AS Dx1, 
 RTRIM (ISNULL(T2.Diag_code,'')) AS Dx2, 
 RTRIM (ISNULL(T3.Diag_code,'')) AS Dx3, 
 RTRIM (ISNULL(T4.Diag_code,'')) AS Dx4

FROM         
 Charge CHG
 INNER JOIN Patient ON CHG.Pat_ID1 = Patient.Pat_ID1 
 INNER JOIN CPT ON CHG.PRS_ID = CPT.PRS_ID 
 INNER JOIN Ident ON Patient.Pat_ID1 = Ident.Pat_Id1 
 INNER JOIN Admin ON Patient.Pat_ID1 = Admin.Pat_ID1
 INNER JOIN Facility ON CHG.Rend_FAC_ID = Facility.FAC_ID 
 LEFT OUTER JOIN Staff ON CHG.Staff_Id = Staff.Staff_ID
 LEFT OUTER JOIN Topog T1 ON CHG.TPG_ID1 = T1.TPG_ID
 LEFT OUTER JOIN Topog T2 ON CHG.TPG_ID2 = T2.TPG_ID
 LEFT OUTER JOIN Topog T3 ON CHG.TPG_ID3 = T3.TPG_ID
 LEFT OUTER JOIN Topog T4 ON CHG.TPG_ID4 = T4.TPG_ID
 WHERE  
CONVERT(CHAR(8),Exported_Prof_DtTm,112) between @StartOfMonth and @EndOfMonth /*using only prof export date*/
and CPT.Billable in ('3','2') /*Prof and Tech only for */
and Facility.Name like 'UNMMG%'
 
ORDER BY 
 LastName, DOS
