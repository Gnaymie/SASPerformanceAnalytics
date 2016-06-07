%macro Total_Risk_test1(keep=FALSE);
%global pass notes;

%if &keep=FALSE %then %do;
	filename x temp;
%end;
%else %do;
	filename x "&dir\Total_Risk_test1_submit.sas";
%end;

data _null_;
file x;
put "submit /r;";
put "require(PerformanceAnalytics)";
put "prices = as.xts(read.zoo('&dir\\prices.csv',";
put "                 sep=',',";
put "                 header=TRUE";
put "                 )";
put "		)";
put "returns = na.omit(Return.calculate(prices))";
put "tr <- function (Ra, Rb, Rf = 0) {";
put "  Period = Frequency(Ra)";
put "  n=length(Rb)";
put "  result = sqrt((SystematicRisk(Ra,Rb,Rf))^2 + (SpecificRisk(Ra,Rb,Rf) * sqrt(n/(n-1)))^2)";
put "  return(result)";
put "  ";
put "}";
put "returns = tr(returns[, 1:4], returns[, 5], Rf= 0.01/252)";
put "endsubmit;";
run;

proc iml;
%include x;

call importdatasetfromr("returns_from_R","returns");
quit;

data prices;
set input.prices;
run;

%return_calculate(prices,updateInPlace=TRUE,method=DISCRETE)
%Total_Risk(prices, BM= SPY, Rf= 0.01/252, scale= 252, VARDEF=DF)

/*If tables have 0 records then delete them.*/
proc sql noprint;
 %local nv;
 select count(*) into :nv TRIMMED from Risk_total;
 %if ^&nv %then %do;
 	drop table Risk_total;
 %end;
 
 select count(*) into :nv TRIMMED from returns_from_r;
 %if ^&nv %then %do;
 	drop table returns_from_r;
 %end;
quit ;

%if ^%sysfunc(exist(Risk_total)) %then %do;
/*Error creating the data set, ensure compare fails*/
data Risk_total;
	IBM = -999;
	GE = IBM;
	DOW = IBM;
	GOOGL = IBM;
	SPY = IBM;
run;
%end;

%if ^%sysfunc(exist(returns_from_r)) %then %do;
/*Error creating the data set, ensure compare fails*/
data returns_from_r;
	IBM = 999;
	GE = IBM;
	DOW = IBM;
	GOOGL = IBM;
	SPY = IBM;
run;
%end;


proc compare base=returns_from_r 
			 compare=Risk_total 
			 out=diff(where=(_type_ = "DIF"
			            and (fuzz(IBM) or fuzz(GE) or fuzz(DOW) 
			              or fuzz(GOOGL))
					))
			 noprint;
run;


data _null_;
if 0 then set diff nobs=n;
call symputx("n",n,"l");
stop;
run;

%if &n = 0 %then %do;
	%put NOTE: NO ERROR IN TEST TOTAL_RISK_TEST1;
	%let pass=TRUE;
	%let notes=Passed;
%end;
%else %do;
	%put ERROR: PROBLEM IN TEST TOTAL_RISK_TEST1;
	%let pass=FALSE;
	%let notes=Differences detected in outputs.;
%end;

%if &keep=FALSE %then %do;
	proc datasets lib=work nolist;
	delete prices diff returns_from_r Risk_total;
	quit;
%end;

filename x clear;

%mend;

