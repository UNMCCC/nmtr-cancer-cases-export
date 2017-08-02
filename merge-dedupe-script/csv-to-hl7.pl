#############################################################
#
#  csv to hl7 adt a08
#
#############################################################
#
#   input MRN, FN, MN, LN, Sx,Race, St, City, Sta, ZIP. SSN, DOB, 
#   input DOD,Expired, DOC, Physic, Dx1, Dx3, Dx4, CPTCode, CPTDes
#
# Output
# 
#  MSH|^~\&|MosaiQ||||||ADT^A08|60921_7570_VI|||||||||  
#  EVN|A08|200710180935|200710180935||HJB|
#  PID|1|177893|177893^^^^MR^MH~0446660000^^^^SS^MH||TESTPAT^B^A^^^||19600415|M|TESTPAT^JOHN^^^^|C|1 SPRING ST^^MAINVILLE^ST^00001-1000^US||8885552222|||M|CNG|21440200|||||ST||||N|||N|
#  DG1|1|I9|153.9|MALIGNANT NEO COLON NOS||D|||Y|
#  DG1|2|I9|784.2|SWELLING IN HEAD   NECK||D|||Y|
#  DG1|3|I9|197.0|SECONDARY MALIG NEO LUNG||D|||Y|
#
#  To dedupe, do not rely on SSN
#
# MSH-10, MessageControlID - must contain a non-blank value; the value should be a
# number or other identifier that uniquely identifies the message among all message 
# received by the CAS Listener.    The CAS Listener echoes this ID back to the sending 
# system in the message acknowledgement. 
# PID |1 |  177893 |       177893^^^^MR^MH~0446660000^^^^SS^MH||TESTPAT^B^A^^^|
#
#PID|1|2|MRN|4|Last^First^Middle^Suffix|6|DOB|SEX|9|Race^Ethnic|Add-st^Add-other^Add-city^Add-St^Add-ZIP^^^^Add-County|12|Add-Phone|14|15|MaritalSt|Religion|18|SocialSecurity#|20|21|22|Birthplace
#
##############################################################
use strict;
my $file; my $outfile;
my $clp_code;
my $line;
my @tumorcase; 
my @docfiles;
my $now;
my $oldmrn;
my $oldssn;
my $olddob;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) ;
my ($mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob);
my ($dod,$expired, $dos, $physic, $dx1, $dx2, $dx3, $dx4, $cptcode, $cptdes,$vitalflag,$ethnic);
my $fullname; my @fname;
my %unmccc=();
my %icd10=(); my %icd9=();
my ($code9,$code9def,$code10,$code10def);
my ($desc1, $desc2, $desc3, $desc4);
my ($cdesc1, $cdesc2, $cdesc3, $cdesc4);
my ($csys1, $csys2, $csys3, $csys4);

open(ICD10,"icd10cm_codes_2017.txt") or die "Couldnt open lookup table for icd 10 icd10cm_codes_2017 \n";
while(<ICD10>){
   /\s+/;
   $code10 = $`;
   $code10def = $';
   $code10def =~ s/\r\n//;
   $code10def =~ s/\n//;
   $icd10{$code10} = $code10def;
}
close(ICD10);

open(ICD9,"CMS32_DESC_SHORT_DX.txt") or die "Couldnt open lookup table for icd 9 CMS32_DESC_SHORT_DX \n";
while(<ICD9>){
   /\s+/;
   $code9 = $`;
   $code9def = $';
   $code9def =~ s/\r\n//;
   $code9def =~ s/\n//;
   $icd9{$code9} = $code9def;
}
close(ICD9);

#my @fruits = keys %icd9;
#for my $fruit (@fruits) {
#    print "The color of '$fruit' is $icd9{$fruit}\n";
#}

##
##  read all in a string  
undef $/;

opendir(DIR,".") or die "$!";
@docfiles = grep(/\w+/, readdir(DIR));
closedir(DIR);
##
## Iterate through all the  files. 
##
    
foreach $file (@docfiles) {

  if (  ($file=~/\.hl7/) || ($file=~/\.pl/) ){ 
     next;   # Do not process processed files.
  }elsif ($file =~/\.csv/){

    if ($file=~/^PFS/){
      ## file parsed with UNMH style
     
      open(DOC, "$file") or print("Error opening $file $!\n");
      my $file_as_string = <DOC>;
      close(DOC);
     
      my @tfile = split(/\n/,$file_as_string);     
      
      foreach $line (@tfile){
         @tumorcase = split(/,/,$line);
         $last = $tumorcase[0]; #print "Size tc  $#tumorcase , FNAME $fullname\n";
         $last =~ s/^"//;       
         @fname = split(/\s/,$tumorcase[1]);
         $first  = $fname[0];
         $first =~ s/"$//;
         $middle = $fname[1];
         $middle =~ s/"$//;
         $street = $tumorcase[2];
         $city = $tumorcase[3];
         $state = $tumorcase[4];
         $zip = $tumorcase[5];
         $race = $tumorcase[6];
         $sex = $tumorcase[7];
         $ssn = $tumorcase[8];
         $dob = $tumorcase[9];
         $dod = $tumorcase[11];
         if ($dod =~ /X/){$dod=1};
         $mrn = $tumorcase[12]; 
         $physic = $tumorcase[10];
         $dx1 = $tumorcase[14]; 
         $dx2 = $tumorcase[15];
         $dx3 = $tumorcase[16];
         $dx4 = $tumorcase[17]; 
         $dos = $tumorcase[18]; 
 
         my $temp = $mrn . '-' . $dob;  #  print "$temp\n";
         $unmccc{$temp}{"$dos"}  = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $dx1, $dx2, $dx3, $dx4, $cptcode, $cptdes";
      }
    }else{
      # file is UNMCCC
      # Read the contents of the PT file
      open(DOC, "$file") or print("Error opening $file $!\n");
      my $file_as_string = <DOC>;
      close(DOC);##  print "file closed \n";
     
       my @tfile = split(/\n/,$file_as_string);      #    print "Size TC is $#tumorcase \n";
     
       foreach $line (@tfile){

         @tumorcase = split(/,/,$line);
         $mrn = $tumorcase[0]; #print "Size tc  $#tumorcase , MRN $mrn\n";
         $first  = $tumorcase[1];
         $middle = $tumorcase[2];
         $last = $tumorcase[3]; 
         $sex = $tumorcase[4];
         $race = $tumorcase[5];
         $street = $tumorcase[6];
         $city = $tumorcase[7]; 
         $state = $tumorcase[8];
         $zip = $tumorcase[9];
         $ssn = $tumorcase[10];
         $dob = $tumorcase[11];
         $dod = $tumorcase[12];
         $expired = $tumorcase[13];
         $dos = $tumorcase[14]; 
         $physic = $tumorcase[15];
         $dx1 = $tumorcase[16]; 
         $dx2 = $tumorcase[17];
         $dx3 = $tumorcase[18];
         $dx4 = $tumorcase[19]; 
         $cptcode = $tumorcase[20]; 
         $cptdes = $tumorcase[21]; 
         my $temp = $mrn . '-' . $dob;  #  print "$temp\n";
         $unmccc{$temp}{"$dos"}  = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $dx1, $dx2, $dx3, $dx4, $cptcode, $cptdes";
       }
     }
       
       ##
       ## dedupe
       ##
  }
  my $i=0;my $outfiled;

  foreach my $mrndob (sort keys %unmccc) {
       foreach my $dates ( sort keys %{$unmccc{$mrndob}}) {
           $i++;
           $outfile='unmccc'. $i.'.hl7';
           $outfiled = 'unmccc'. $i;
      
            #print " $mrndob, $dates: $unmccc{$mrndob}{$dates}\n";
           @tumorcase = split(/,/,$unmccc{$mrndob}{$dates});
           for (my $j=0 ; $j<=21; $j++){
              $tumorcase[$j] =~ s/^\s+|\s+$//g;
           } 
           $mrn = $tumorcase[0]; #print "Size tc  $#tumorcase , MRN $mrn\n";
           $first  = $tumorcase[1];
           $middle = $tumorcase[2];
           $last = $tumorcase[3]; 
           $sex = $tumorcase[4];
           $race = $tumorcase[5];
           if ($race =~ s/Hispanic//){
             $ethnic = 'Hispanic';
           }
           $street = $tumorcase[6];
           $city = $tumorcase[7]; 
           $state = $tumorcase[8];
           $zip = $tumorcase[9];
           $ssn = $tumorcase[10];
           if($ssn==999999999){undef($ssn);}
           $dob = $tumorcase[11];
           $dod = $tumorcase[12];
           $expired = $tumorcase[13];
           if (($dod=~/\d/) || ($expired =~ /\d/)){
             $vitalflag='D';
           }
           $dos = $tumorcase[14]; 
           $physic = $tumorcase[15];
           $dx1 = $tumorcase[16];
           $dx2 = $tumorcase[17];
           $dx3 = $tumorcase[18];
           $dx4 = $tumorcase[19];
           $cptcode = $tumorcase[20]; 
           $cptdes = $tumorcase[21];
           
           if ($dx1=~/\d+/) { 
             $dx1 =~ s/\.//g;
             $cdesc1 = $icd9{$dx1} ;
             if($cdesc1=~/\w+/){ 
                $csys1 ='I9';
             }else{
                $cdesc1 = $icd10{$dx1} ;
                if($cdesc1=~/\w+/){ 
                  $csys1 ='I10';
                }
             }
             open(FOUT, ">", $outfile)  or die "Couldnt write to hl7 $outfile";
             print FOUT 'MSH|^~\&|MosaiQ||||||ADT^A08|' . $outfiled . '|||||||||' . "\r\n";
             print FOUT 'EVN|A08|' . $dos . '||HJB|' . "\r\n";  #could be DOS or Time of export.
             print FOUT 'PID|1||' . $mrn . '||' . $last . '^' . $first . '^' . $middle . '||' . $dob . '|' . $sex . '||' . $race . '|' . $street . '^^' . $city . '^' . $state . '^' .$zip . '||||||||' . $ssn . '|||' . $ethnic . '||||||||' . $vitalflag . "\r\n";
             print FOUT 'DG1|1|' . $csys1. '|' . $dx1 . '|' . $cdesc1 . '||D|||Y|' . "\r\n";
           }
           if ($dx2=~/\d+/) { 
             $dx2 =~ s/\.//g;
             $cdesc2 = $icd9{$dx2} ;
             if($cdesc2=~/\w+/){ 
                $csys2 ='I9';
             }else{
                $cdesc2 = $icd10{$dx2} ;
                if($cdesc2=~/\w+/){ 
                  $csys2 ='I10';
                }
             }
             open(FOUT, ">", $outfile)  or die "Couldnt write to hl7 $outfile";
             print FOUT 'MSH|^~\&|MosaiQ||||||ADT^A08|' . $outfiled . '|||||||||' . "\r\n";
             print FOUT 'EVN|A08|' . $dos . '||HJB|' . "\r\n";  #could be DOS or Time of export.
             print FOUT 'PID|1||' . $mrn . '||' . $last . '^' . $first . '^' . $middle . '||' . $dob . '|' . $sex . '||' . $race . '|' . $street . '^^' . $city . '^' . $state . '^' .$zip . '||||||||' . $ssn . '|||' . $ethnic . '||||||||' . $vitalflag . "\r\n";
             print FOUT 'DG1|1|' . $csys2 . '|' . $dx2 . '|' . $cdesc2 . '||D|||Y|' . "\r\n";
           }
           if ($dx3 =~ /\d+/) { 
             $dx3 =~ s/\.//g;
             $cdesc3 = $icd9{$dx3} ;
             if($cdesc3=~/\w+/){ 
                $csys3 ='I9';
             }else{
                $cdesc3 = $icd10{$dx3} ;
                if($cdesc3=~/\w+/){ 
                  $csys3 ='I10';
                }
             }
             open(FOUT, ">", $outfile)  or die "Couldnt write to hl7 $outfile";
             print FOUT 'MSH|^~\&|MosaiQ||||||ADT^A08|' . $outfiled . '|||||||||' . "\r\n";
             print FOUT 'EVN|A08|' . $dos . '||HJB|' . "\r\n";  #could be DOS or Time of export.
             print FOUT 'PID|1||' . $mrn . '||' . $last . '^' . $first . '^' . $middle . '||' . $dob . '|' . $sex . '||' . $race . '|' . $street . '^^' . $city . '^' . $state . '^' .$zip . '||||||||' . $ssn . '|||' . $ethnic . '||||||||' . $vitalflag . "\r\n";
             print FOUT 'DG1|1|' . $csys3 . '|' . $dx3 . '|' . $cdesc3 . '||D|||Y|' . "\r\n";
           }
           if ($dx4=~ /\d+/) { 
            $dx4 =~ s/\.//g;
            $cdesc4 = $icd9{$dx4} ;
             if($cdesc4=~/\w+/){ 
                $csys4 ='I9';
             }else{
                $cdesc4 = $icd10{$dx4} ;
                if($cdesc4=~/\w+/){ 
                  $csys4 ='I10';
                }
             }
             open(FOUT, ">", $outfile)  or die "Couldnt write to hl7 $outfile";
             print FOUT 'MSH|^~\&|MosaiQ||||||ADT^A08|' . $outfiled . '|||||||||' . "\r\n";
             print FOUT 'EVN|A08|' . $dos . '||HJB|' . "\r\n";  #could be DOS or Time of export.
             print FOUT 'PID|1||' . $mrn . '||' . $last . '^' . $first . '^' . $middle . '||' . $dob . '|' . $sex . '||' . $race . '|' . $street . '^^' . $city . '^' . $state . '^' .$zip . '||||||||' . $ssn . '|||' . $ethnic . '||||||||' . $vitalflag . "\r\n";
             print FOUT 'DG1|1|' . $csys4 . '|' . $dx4 . '|' . $cdesc4 . '||D|||Y|' . "\r\n";
           }
           if ($cptcode) {print 'DG1|1|I10|' . $cptcode .'|' . $cptdes . '||||||';}
           undef $ethnic;
           $vitalflag = 'A';
           close(FOUT);
           last;              ## at this point, the records are sorted by mrn-dob AND DOs pick the first, and exit innerloop.

       }
  }
}