******************************************************************************;
* Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA               *;
*                                                                            *;
* Licensed under the Apache License, Version 2.0 (the "License");            *;
* you may not use this file except in compliance with the License.           *;
* You may obtain a copy of the License at                                    *;
*                                                                            *;
*   http://www.apache.org/licenses/LICENSE-2.0                               *;
*                                                                            *;
* Unless required by applicable law or agreed to in writing, software        *;
* distributed under the License is distributed on an "AS IS" BASIS,          *;
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *;
* See the License for the specific language governing permissions and        *;
* limitations under the License.                                             *;
******************************************************************************;

******************************************************************************;
* SECTION 3 - XML, JSON, and text                                            *;
******************************************************************************;

* define git_repo_dir macro variable;
%let git_repo_dir = /home/jphall0/SAS_Workshop;

* set directory separator;
%let dsep = /; /* comment line for windows (but not for unversity edition) */
* %let dsep = \; /* uncomment line for windows */

*** XML **********************************************************************;

* one way to process semi-structured XML data using SAS;
* is the SAS XML libname;
* PROC GROOVY provides another method to ingest JSON using SAS;

* define a library reference to the example.xml file;
* then you can treat it like a SAS data set;
libname x xml92 "&git_repo_dir";

* read data into SAS work;
* create scratch set;
data scratch;
	set x.example;
run;

* data cleaning exercise;
* fix variable1 to have 2 decimal points;
* fix variable2 to be a numeric variable;
* converting a character variable to a numeric variable (and vise versa);
* is a common data cleaning operation in SAS;
* formatted variables are also common in SAS;
* recreate scratch set;
data scratch;

	/* rename variable2 before it is read */
	/* use length statement before set statement */
	/* to enforce order of variables in the new set */
	/* and to define new variable2 as numeric explicitly */
	
	/* input() function converts a character value into a numeric value */
	/* ?? prevents an error when an invalid value is encountered */
	/* best. is a SAS informat */
	/* it determines the best format for reading variable2c */
	
	/* compress() removes white space from characters */
	
	/* account for invalid data */
	/* convert numeric missing to code: 99 */
	
	/* 10.2 format limits variable1 to 10 digits with 2 decimal points */
	/* 2. format limits variable2 to 2 digits */
	
	/* drop variable2c in data step */

	length variable1 variable2 8 variable3 $6;
	set scratch (rename=(variable2=variable2c));
	variable2 = input(compress(variable2c), ?? best.);
	if variable2 = . then variable2 = 99;
	format variable1 10.2;
	format variable2 2.;
	drop variable2c;
run;

* write the clean temp data back to XML;
data x.clean_example;
	set scratch;
run;

* deassign libref x;
libname x;

*** JSON *********************************************************************;

* one way to process semi-structured JSON data using SAS;
* is the newish JSON library engine;

* create a file reference to the example.json file;
filename json "&git_repo_dir.&dsep.example.json";

* create a library reference to the file reference;
libname j JSON fileref=json;

* use data step and SAS formats;
* to tidy up JSON input;
* recreate scratch2 set;
data scratch2;
	format variable1 10.2;
	format variable2 2.;
	length variable1 variable2 8 variable3 $6;
	set j.row (drop=ordinal_:);
run;

* deassign fileref json;
filename json; 

* deassign library reference j;
libname j;

*** text *********************************************************************;

* create a file reference to the example.txt file;
* each line contains a tweet; 
filename txt "&git_repo_dir.&dsep.example.txt";

* each line will be one line of the data set;
* create scratch3 set;
data scratch3;
	length line $140.;          /* tweets are 140 characters */
	infile txt delimiter='0a'x; /* hex character for line return; ascii table-Hex 16 */
	informat line $140.;
	input line $;
run;

* basic text normalization;
* use data step functions including prx functions;
* regular expressions are a flexible tool for manipulating text;
* SAS surfaces regular expressions through the prx functions;
* recreate scratch3 set;
data scratch3;

	/* compile regular expression */
	/* find http* and replace with one blank space */
	/* all text to lower case */
	/* use regular expression to remove urls */
	/* remove non-alphabetical characters */

	regex = prxparse('s/http.*( |)/ /'); /* anything followed by http replace it with a blank */
	length line $140.; 
	infile txt dlm='0a'x; 
	informat line $140.;
	input line $;
	line = lowcase(line);
	call prxchange(regex, -1, line);
	line = compress(line, '?@#:&!".');
	drop regex;
run;

*** create a term by document (tbd) matrix ***********************************;

* term by document matrix is often represented by rows of 3-tuples;
* (document ID, term ID, term count);
* a term by document matrix in this format is suitable for text mining;

* first step toward creating a tbd matrix; 
* transpose wide data into long data;
* create scratch4 set;
data scratch4;

	/* give each tweet a numeric ID using a retained variable*/
	/* use a do loop to put each term into its own row */
	/* scan() function returns the ith element of a delimited list */
	/* remove short terms that are usually not informative */
	
	set scratch3;
	retain tweet_id 1; /* retain to count */
	n_terms = countw(line);
	do i=1 to n_terms;
		term = scan(line, i);
		if length(term) > 2 then output;
	end;
	tweet_id + 1;
	drop line n_terms i;
run;

* create a dictionary of unique terms;
* add term ID number to dictionary;
proc sort
	data=scratch4(keep=term)
	out=dictionary
	/* remove duplicate terms */
	nodupkey;
	by term;
run;
data dictionary;
	set dictionary;
	term_id = _n_;
run;

* sort scratch4 set by term and join to term IDs;
proc sort
	data=scratch4;
	by term;
run;
data scratch4;
	merge scratch4 dictionary;
	by term;
run;

* create term by document matrix;
* use by variables and a retained variable;
* to count terms in each tweet;
proc sort
	data=scratch4;
	by tweet_id term_id;
run;
data tbd;
	set scratch4;
	by tweet_id term_id;
	retain count 0;
	if first.term_id then count = 0;
	count + 1;
	keep tweet_id term_id count;
run;
