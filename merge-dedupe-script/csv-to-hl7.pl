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
#
#  About inputs.
#  PFS
# 0,                       1,                       2,              3,                  4,          5,                    6,                   7,     8,                        9,              10,                     11,                 12,                       13,     14,       15,                  16,               17.
# Patient_Name, Guar_Address, Guar_City, Guar_State, Guar_Zip, Patient_Race, Patient_Gender, SSN, Patient_DOB, Attending_Dr, Death_Indicator, Patient_MRN, Hospital_Service, ICD9, ICD10, DX_PRIORITY, DX_CODE,adm_date
# ABC  DEF, 1234 SCARL GEM CT NE, Albuquerque, NM, 87000, C,                   F,     123-45-6789, 11/22/1800, QUINTANA DULCINEA D MD,         , 88MRN88,         C-C,                 ,       ,          ,                       ,                 , 1/5/2018
#
##############################################################
use strict;
use Data::Dumper qw(Dumper);

##
##  declarations
##
my $sizename;
my $file; my $outfile; my $source;
my $clp_code; my $line; my $true; my $false = 0;
my $unmhfile_as_string ; my $unmcccfile_as_string ;
my $unmhfilename; my $unmcccfilename;
my @tumorcase;  my @docfiles;
my $now; my $oldmrn; my $oldssn; my $olddob;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) ;
my ($mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$phone);
my ($dod,$expired, $dos, $physic, $dx1, $dx2, $dx3, $dx4, $cptcode, $cptdes,$vitalflag,$ethnic);
my ($dx,$dxOrder,$icd10,$icd9,$icd10P);
my $fullname; my @fname; my $fi; my $ii; my $tt;
my %unmccc=();
my %icd10=(); my %icd9=();
my ($code9,$code9def,$code10,$code10def,$orig_code);
my ($desc1, $desc2, $desc3, $desc4);
my ($cdesc1, $cdesc2, $cdesc3, $cdesc4);
my ($csys1, $csys2, $csys3, $csys4);
my $kkk = 0; my $jjj = 0;

#
#  make a lookup table for ICD-10 codes and definitions.
#
open(ICD10,"icd10cm_codes_2018.txt") or die "Couldnt open lookup table for icd 10 icd10cm_codes_2018 \n";
while(<ICD10>){
   /\s+/;                                                                                                     ## Match space(s)
   $code10 = $`;                                                                                    ## code is before space
   $code10def = $';                                                                               ##  code definition is after space
   $code10def =~ s/\r\n//;                                                                     ## remove newlines
   $code10def =~ s/\n//;                                                                       ##
   $icd10{$code10} = $code10def;                                                    ##  make an code-codedef entry in assoc. array (hash)
}
close(ICD10);

#
#  make a lookup tables for ICD-9 codes and their definitions
#
open(ICD9,"CMS32_DESC_SHORT_DX.txt") or die "Couldnt open lookup table for icd 9 CMS32_DESC_SHORT_DX \n";
while(<ICD9>){
   /\s+/;                                                                                                 ## Match space(s)
   $code9 = $`;                                                                                   ## code is before space
   $code9def = $';                                                                              ##  code definition is after space
   $code9def =~ s/\r\n//;                                                                    ## remove newlines
   $code9def =~ s/\n//;                                                                      ##
   $icd9{$code9} = $code9def;                                                       ##  make an code-codedef entry in assoc. array (hash)
}
close(ICD9);

##
##  Scan the current folder for files in it.
##  
opendir(DIR,".") or die "$!";
@docfiles = grep(/\w+/, readdir(DIR));
closedir(DIR);

##############
## Iterate through all the  files in folder, whether UH or UNMCCC, exclude excel, scripts or processed files.
##     1) Parse out file, sort and clean information
##     2) Dedupe and output HL7s
##
###############

## 1) Parse each source data file into assoc. array.
foreach $file (@docfiles) {  
  if (  ($file=~/\.hl7/) || ($file=~/\.pl/)  || ($file=~/\.xls/) || ($file=~/\.xlsx/)){ 
       next;   # Do not process processed files or excel or scripts.
  }elsif ($file =~/\.csv/){
       ##
       ## Non-UNMCCC files are somewhat different from the UH files.
       if ($file=~/^PFS/){
            ### file parsed with UNMH style
             $source = 'Cerner';
             $unmhfilename = $source.'-'.$file;     
             open(DOC, "$file") or print("Error opening $file $!\n");
             my @tfile = <DOC>;
             close(DOC);
             ##   print "Size UNMHTFILE is $#tfile \n ";
            
             shift(@tfile);
             foreach $line (@tfile){
                        @tumorcase = split(/,/,$line);
                        $street = $tumorcase[0];  $city = $tumorcase[1];
                        $state = $tumorcase[2];   $zip = $tumorcase[3];
                        $race = $tumorcase[4];    $sex = $tumorcase[5];
                        $ssn = $tumorcase[6];     $dob = convertdate($tumorcase[7]);
                        ## Problem with file source.   Two types of rows 
                       ## From column "DR" on, there may be an extra column --  DR. Name may be broken in two or more parts.
                       ## Then the row will have an EXTRA column.  THat's your cue to decide what's what.
                       ## CHECK how many columns (18 or 19?) to decide what to do.
                       if ($#tumorcase ==19){
                             $physic = $tumorcase[8];    
                             $dod = $tumorcase[9];
                             if ($dod =~ /X/){$dod=1};       #turn deceased flag into boolean
                             $mrn = $tumorcase[10]; 
                             $icd9 = $tumorcase[12];                          ##icd9             ALWAYS EMPTY
                             $icd10P = $tumorcase[13];                      ## icd10           PRIMARY DIAG
                             $dxOrder = $tumorcase[14];                    ##dx  priority     order in priority (primary, second..)
                             $icd10 = $tumorcase[15];                         ## icd10          secondary / comorb.
                             $dos = convertdate($tumorcase[16]); 
                             $last  = $tumorcase[17]; $first = $tumorcase[18]; $middle = $tumorcase[19];
                        }elsif($#tumorcase==20){
                             $physic = $tumorcase[8] . ' ' . $tumorcase[9];  
                             $dod = $tumorcase[10];
                             if ($dod =~ /X/){$dod=1};
                             $mrn = $tumorcase[11];
                             $icd9 = $tumorcase[13];                         ## icd9             ALWAYS EMPTY
                             $icd10P = $tumorcase[14];                     ## icd10           PRIMARY
                             $dxOrder = $tumorcase[15];                   ## dx priority... ORDER OF PRIOR.
                             $icd10 = $tumorcase[16];                        ## dx code              secondary
                             $dos = convertdate($tumorcase[17]);
                             $last  = $tumorcase[18]; $first = $tumorcase[19]; $middle = $tumorcase[20];
                        }
                        my $temp = $mrn . '-' . $dob;                       ## Associative array key MRN+DOB
                        if ($dxOrder !~/\d/){  
                                  $dxOrder =1;                                        #default the Diag priority to 1 (primary) when column has no data.
                        }else{
                                  $dxOrder = $dxOrder + 0;                   ##cast as integer ("02", etc).
                        }
                        ## 
                        ##    3 DIff. possibilities. 
                        ##             1) Row for this encounter has NO DX at all. Ignore
                        ##             2) Row for this encounter has only Primary DX.  Grab.
                        ##             3) Encounter has DIX
                        if ($icd10P !~ /\w/){ 
                        }else{
                             if($icd10 =~/\w/){
                                    if ($dxOrder>1){  
                                          $unmccc{$temp}{$dos}{$dxOrder}  = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $icd10,$source";
                                    }else{
                                          $unmccc{$temp}{$dos}{1}  = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $icd10P,$source";
                                    }
                             }
                        }
                        $kkk++;
             }     ## final line / end of this PFS file  / close foreach loop.
           
       }else{
             # File is UNMCCC
             $source = 'Mosaiq';
             # Read the contents of the PT file
             $unmcccfilename = $source .'-'. $file;      
             open(DOC, "$file") or print("Error opening $file $!\n");
             my @tfile = <DOC>;      
             close(DOC);                              ##      print "Size UNMCCCFILE is $#tfile \n ";
             shift(@tfile);                              ##    remove headerline
             shift(@tfile);                              ##    remove second line with dashes.         
             foreach $line (@tfile){
                        @tumorcase = split(/,/,$line);
                       $mrn = $tumorcase[0];  $first  = $tumorcase[1];  $middle = $tumorcase[2];   $last = $tumorcase[3]; 
                       $sex = $tumorcase[4];  $race = $tumorcase[5];  $street = $tumorcase[6];   $city = $tumorcase[7]; 
                       $state = $tumorcase[8];  $zip = $tumorcase[9];  $ssn = $tumorcase[10];
                       $dob = convertdate($tumorcase[11]);
                       $dod = convertdate($tumorcase[12]);
                       $expired = convertdate($tumorcase[13]);
                       $dos = convertdate($tumorcase[14]); 
                       $physic = parseUnmCccName($tumorcase[15]);
                       $dx1 = $tumorcase[16];   ## primary -- well, maybe.
                       $dx2 = $tumorcase[17];   ## 1st secondarty
                       $dx3 = $tumorcase[18];   ## 2nd second
                       $dx4 = $tumorcase[19];   ## third.
                       $phone = $tumorcase[20];  ## the home phone or cell.
                       $phone =~s/\n//;
                       my $temp = $mrn . '-' . $dob;      ## Associative array key MRN+DOB
                       ##
                       ##  See how many DXs in this record
                       if($dx1 =~/\w/){
                              $unmccc{$temp}{$dos}{1} = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $dx1,$source,$phone";
                       }
                       if($dx2 =~/\w/){
                              $unmccc{$temp}{$dos}{2} = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $dx2,$source,$phone";
                       }
                       if($dx3 !~/\w/){
                              $unmccc{$temp}{$dos}{3} = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic, $dx,$source,$phone";
                       }
                       if($dx4=~/\w/){
                             $unmccc{$temp}{$dos}{4} = "$mrn, $first, $middle, $last, $sex,$race, $street, $city, $state, $zip,$ssn,$dob,$dod,$expired, $dos, $physic,$dx,$source,$phone";
                       }
                       $jjj++;
             }
       }  ## END of IF, where we check whether this was UH/PFS or UNMCCC
       
       print "Lines $unmcccfilename UNMCC parsed: $jjj \n Lines $unmhfilename  UH parsed $kkk\n";

       $jjj =  0; $kkk = 0;
       ##
       ## dedupe
       ##
  }    ## END OF IF, where we check whether this was a parseable file source.
  
}    ## End of processing for this file, accumulate data for next file.


##
## 2) Once info is in associative (hash) arrays, we dedupe it, and output as HL7.

my $i=0;my $outfiled;
foreach my $mrndob (sort keys %unmccc) {
       foreach my $dates ( sort keys %{$unmccc{$mrndob}}) {
               my $plaindate = $dates;  $plaindate =~ s/\s+//g;  
               my $plainmrndob = $mrndob;  $plainmrndob =~ s/\s+//g;$plainmrndob=~s/\"//g;
              
               ##
               ##  get the first record with mrn-dob-dos and valid DX.
               $true =1;
               my $tt = 1;
               while($true){
              
                     if (exists $unmccc{$mrndob}{$dates}{$tt}){
                         
                           @tumorcase = split(/,/,$unmccc{$mrndob}{$dates}{$tt});
                            for (my $j=0 ; $j<=21; $j++){
                                  $tumorcase[$j] =~ s/^\s+|\s+$//g;                                                            # strip white/blank spaces
                                   $tumorcase[$j] =~ s/\"//g;                                                                        # strip quotes
                            } 
                            $mrn = $tumorcase[0];   $first  = $tumorcase[1];  $middle = $tumorcase[2];     $last = $tumorcase[3]; 
                            $sex = $tumorcase[4];   $race = $tumorcase[5];
                            if ($race =~ s/Hispanic//){
                                  $ethnic = 'Hispanic';
                            }
                            $street = $tumorcase[6];  $city = $tumorcase[7];  $state = $tumorcase[8]; $zip = $tumorcase[9];
                            $ssn = $tumorcase[10];
                            if($ssn==999999999){undef($ssn);}
                            $dob = convertdate($tumorcase[11]); $dod = convertdate($tumorcase[12]); $expired = convertdate($tumorcase[13]);
                            if (($dod=~/\d/) || ($expired =~ /\d/)){
                                   $vitalflag='D';
                            }
                            $dos = convertdate($tumorcase[14]);     $physic = $tumorcase[15];   $dx = $tumorcase[16];  $source = $tumorcase[17];
                            $phone = $tumorcase[18];
                           ##  print "$outfiled SRC: $source outfiled: $outfile.  IT exists at $tt \n";
                            if ($dx=~/\d+/) {
                                   ($csys1, $cdesc1) = getdxdefinition($dx);
                            }
                            $dxOrder = $tt;
                            $true = $false;
                     }else{
                            $tt++;
                            if ($tt>100){
                                   print "LINE outfiled: $outfile.  IT BAILING OUT at $tt \n";
                                   print Data::Dumper->Dump([$unmccc{$mrndob}]);
                                   $true = $false;
                            }
                     }
               }   
               $outfiled = 'unmccc'. $mrndob . $dates;
               $outfile   = $source .'-'. $plainmrndob . $plaindate . '.hl7';  
              
               open(FOUT, ">", $outfile)  or die "Couldnt write to hl7 $outfile";   
               print FOUT 'MSH|^~\&|' . $source . '||||||ADT^A08|' . $outfiled . '|||||||||' . "\r\n";
               print FOUT 'EVN|A08|' . $dos . '||HJB|' . "\r\n";  #could be DOS or Time of export.
               print FOUT 'PID|1||' . $mrn . '||' . $last . '^' . $first ;
               if ($middle=~/\w/){
                     print FOUT '^' . $middle;
               } 
               print FOUT '||' . $dob . '|' . $sex . '||' . $race . '|' . $street . '^^' . $city . '^' . $state . '^' .$zip . '||' . $phone . '||||||' . $ssn . '|||' . $ethnic . '||||||||' . $vitalflag . "\r\n";
               print FOUT 'PV1|||||||^' . $physic . '||||||||||||||||||||||||||||||||||||||' . $dos . '||||||||'. "\r\n";
               print FOUT 'DG1|' . $dxOrder . '|' . $csys1. '|' . $orig_code . '|' . $cdesc1 . '||D|||Y|' . "\r\n";
               ##
               ## loop over all other possible DiagX for this mrn-dob-dos.
               for  ($ii=$dxOrder+1; $ii<=50; $ii++){
                     if (exists $unmccc{$mrndob}{$dates}{$ii}){
                          @tumorcase = split(/,/,$unmccc{$mrndob}{$dates}{$ii});
                          $dx = $tumorcase[16];
                          if ($dx=~/\d+/) {
                                 ($csys1, $cdesc1) = getdxdefinition($dx);
                                 print FOUT 'DG1|' . $ii . '|' . $csys1. '|' . $orig_code . '|' . $cdesc1 . '||D|||Y|' . "\r\n";
                          }
                     }
               }
               undef $dx; undef $ethnic; undef $middle;  
               undef $mrn; undef $last; undef $first; undef $dob; undef $sex ; undef $race; 
               undef $street; undef. $city ; undef $state; undef $zip;
               $vitalflag = 'A';
               close(FOUT);
               ##  last;     ## at this point, the records are sorted by mrn-dob AND DOs pick the first, and exit innerloop.     
        }
}


sub  convertdate
{
    my $odat = shift;
    my $dat;
    if ($odat=~/\//){  ## mm/dd/yyyy
       $odat=~/(\d+)\/(\d+)\/(\d+)/;
       $dat = $3.$1.$2;
    }else{
       $dat = $odat ;
    }
    return $dat;
    
}
sub parseUnmCccName
{
   my $fname = shift;
   my @nparts = split(/\s/,$fname);
   my $first = $nparts[0];
   my $f  = substr $first, 0, 1;
   my $last;
   if ($#nparts==1){
      $last = $nparts[1];
   }elsif ($#nparts ==2){
      if( length($nparts[1]) == 2 ){
         $last = $nparts[2];
      }else{
          $last = $nparts[1].' '. $nparts[2];
      }
   }elsif($#nparts>=3){
      if( length($nparts[1]) == 2 ){
         $last = $nparts[2];
      }else{
         $last = $nparts[2] . ' ' . $nparts[3];
      }
   }
   $last = substr $last, 0, 8;   # trim to 8 spaces
   $fname = $f . ' ' . $last;
   return($fname)
}
sub getdxdefinition
{
      my $dx = shift;
      $orig_code = $dx; 
      $dx =~ s/\.//g;
      $cdesc1 = $icd9{$dx} ;
      if($cdesc1=~/\w+/){ 
            $csys1 ='I9';
      }else{
            $cdesc1 = $icd10{$dx} ;
            if($cdesc1=~/\w+/){ 
                  $csys1 ='I10';
            }
      }
      return($csys1, $cdesc1);
}