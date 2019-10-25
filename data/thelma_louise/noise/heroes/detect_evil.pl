:-module(detect_evil, [background_knowledge/2
		      ,metarules/2
		      ,positive_example/2
		      ,negative_example/2
		      ,learning_rates/6
		      ,noise_interval/4
		      ,hero_attributes/2
		      ]).

:-use_module(hero_generator).
:-use_module(heroes_configuration).
% Loads the generated heroes dataset if it exists
% or generates it and then loads it.
:- (exists_file('data/thelma_louise/noise/heroes/heroes.pl')
  ->   reexport(heroes)
   ;   write_dataset
      ,reexport(heroes)
   ).


/** <module> Evil alignment detector for auto-generated heroes dataset.

Hero data is loaded from heroes.pl. See hero_generator.pl for
instructions on how to generate heroes.pl.

Contents of this file
=====================

1. Introductory comments (this section).
2. Experiment settings   [experiment_settings]
3. Experiment logging    [experiment_logging]
4. Experiment code       [experiment_code]
5. MIL problem           [mil_problem]
6. Auxiliary predicates  [auxiliary_preds]

The strings in square braces in the TOC above can be used to search for,
and so jump to, the relevant sections in this file.

Training instructions for simple learning attempt
=================================================

The instructions in this section are for a simple learning attempt,
which is not particularly interesting, given that the problem is a
bog-standard binary classification problem that any propositional
learner can solve easily.

The section immediately following instead documents the more interesting
experiment defined in this file that measures the performance of Thelma
and Louise on a dataset with classification noise.

1.  Set the noise option to 0:

==
noise(0.0)
==

2. Train Louise with the following query:

==
?- learn(alignment/2).
alignment(A,evil):-faith(A,faithless),class(A,priest).
alignment(A,evil):-honour(A,dishonourable),class(A,knight).
alignment(A,evil):-kills(A,scourge),class(A,raider).
true.
==

Example query for learning-rate experiment
==========================================

The experiment predicate, learning_rates/6, defined in this file, will
perform a learning rate experiment varying the amount of classificatoin
noise in the positive examples.

The following query performs a learning rate experiment repeating 10
steps, in each of which 10 learning attempts are made, each with a noise
amount in [0,0.1,0.2,...,0.9] and the sample size determined by
sample_size/1. Classification Error is used to evaluate learned
hypotheses.

==
?- _T = alignment/2, _M = err, _K = 10, detect_evil:noise_interval(0,9,1,_Ps), detect_evil:learning_rates(_T,_M,_K,_Ps,_Ms,_SDs).
==

Results of the experiment are logged to a file placed in the directory
logs/heroes/ and with a filename starting with the string
"detect_evil_err_" followed by a timestamp. The full path to the log
file is determined by the local configuration option dataset_filename/1
(in heroes_configuration.pl).

Logging results include two R vectors, one for means and one for
standard deviations, of the FNR metric, of all learning attempts in each
step. These can then be used to plot the results in R. An R scrip used
for this purpose is included in data/noise/heroes/scripts.


Motivation
==========

This experiment file is meant to compare the performance of Thelma and
Louise in the presence of classification noise, specifically,
misclassified negative examples, i.e. negative examples labelled as
positive.

The expected result is that Louise will handle noise by including any
misclassified negative examples encountered during training in the
learned hypothesis as "exceptions" to the rules in the hypothesis.
Conversely, Thelma will simply fail to learn because of its strict
hypothesis validation that accepts only hypotheses that cover all
positive and no negative examples (such a hypothesis is not possible to
construct given misclassified examples- of any sign). The larger the
sample size used for training, the more often misclassified examples
will be encountered and, consequently, the more often Thelma should fail
to learn.

Unbalanced classes
==================

Note that because the number of negative examples for alignment/2 can be
considerably larger than the number of positive examples, measuring
accuracy/error would not be very informative, unless the numbers of the
two kinds of examples are equalised. Otherwise, a large proportion of
negative examples would be correctly rejected even when learning failed
resulting in a misleadingly high accuracy score (when a learning attempt
fails, the learned hypothesis evaluated is the empty hypothesis, which
rejects everything).

To avoid such confusing results, this experiment file defines a class
balancing predicate, balance/5. Refer to that predicate for more details
on class balancing.

*/

% Uncomment and call make/0 to open generator and configuration files in
% Swi-Prolog IDE when this file is (re)loaded.
%:-edit(hero_generator).
%:-edit(heroes_configuration).

% Declared dynamic to allow manipulation by learning_rate/7.
:-dynamic noise/1.

% Declared dynamic to avoid warnings in misclassify/0.
% alignment/2 is defined in heroes.pl and alignment.pl
% but not found until those are loaded, or after the definitions in
% heroes.pl removed by miclassify/0.
%:-dynamic alignment/2.


%[experiment_settings]
%===============================================================================
% Experiment settings
%===============================================================================

%!	noise(?Amount) is semidet.
%
%	The Amount of noise to add to positive examples.
%
%	"Noise" refers to classification noise and specifically
%	misclassified positive examples.
%
%	Misclassified positive examples are implemented by replacing a
%	positive example with a negative example, both of which are
%	selected at random.
%
%	Amount is a float, denoting the proportion of positive examples
%	that are replaced by negative examples in the results of
%	positive_example/2.
%
%	This option is declared dynamic in order for it to be
%	manipulated by experiment code during execution. The goal is to
%	run learning rate experiments where the amount of noise is
%	progressively increased in each step of the experiment.
%
noise(0.0).


%!	sample_size(?Size) is semidet.
%
%	Sample Size for learning rate experiments.
%
%	Used to set the relative size of the training partition in
%	learning rate experiments defined in this experimet file.
%
%	Learning rate experiments defined in this file are meant to
%	compare the behaviour of Louise and Thelma in the presence of
%	classification noise in the form of negative examples added to
%	the set of positive examples. For such experiments only the
%	noise amount (i.e. the proportion of misclassified positive
%	examples with respect to the total number of positive examples)
%	must vary so the sample size is a constant throughout each
%	experiment step. Therefore, this option is not dynamic, unlike
%	noise/1 which must be manipulated during experiment execution.
%
sample_size(0.8).


%!	time_limit(?Seconds) is semidet.
%
%	Time limit for learning rate experiments.
%
%	Seconds is an integer, the number of seconds any learning
%	attempt will be allowed to continue for, during a learning rate
%	experiment. If that many Seconds pass before a learning attempt
%	completes, the step will end with failure and the empty
%	hypothesis returned.
%
time_limit(5).



% [experiment_logging]
%===============================================================================
% Experiment logging
%===============================================================================

% Uncomment to allow tracking progresss of the experiment to the console.
:-debug(progress).


%!	start_logging(+Metric) is det.
%
%	Start logging to the current log file.
%
%	Opens the log file for a learning rate experiment and begins
%	logging to that file. Log file names are timestamped and begin
%	with "detect_evil_<eval>_" where "eval" is the three-letter
%	atomic name for an evaluation metric, e.g. err for "error", fnr
%	for False Negative Rate etc. Refer to module evaluation for a
%	description of available evaluation metrics.
%
%	Note that this predicate does not attempt to create any
%	sub-directories on the path to the log file. In particular, the
%	output directory logs/heroes/ hard-coded below must exist before
%	logging begins or an existence error will be raised.
%
%	close_log/1 must be called at some point after start_logging/0
%	to flush the output buffer to the log file and close it safely.
%	Otherwise, the log file will remain locked by the Swi-Prolog
%	process under which start_logging was executed.
%
%	@tbd The log file path should not be hard-coded. Add a
%	configuration option to determine it.
%
start_logging(M):-
	close_log(detect_evil)
	,debug_timestamp(T)
	,atomic_list_concat([detect_evil,M,T],'_',Bn)
	,atom_concat(Bn,'.log',Fn)
	,atom_concat('logs/heroes/',Fn,P)
	,open(P,write,S,[alias(detect_evil)])
	,debug(detect_evil>S).


%!	close_log(+Alias) is det.
%
%	Close the log file with the given Alias if it exists.
%
close_log(A):-
	(   is_stream(A)
	->  close(detect_evil)
	;   true
	).


%!	debug_timestamp(-Timestamp) is det.
%
%	Helper predicate to generate a Timestamp for log files.
%
debug_timestamp(A):-
	get_time(T)
	,stamp_date_time(T, DT, local)
	,format_time(atom(A), '%d_%m_%y_%H_%M_%S', DT).


% [experiment_code]
%===============================================================================
% Experiment code
%===============================================================================


%!	learning_rates(+Target,+Metric,+Steps,+Noise,-Means,-SDs) is
%!	det.
%
%	Perform a learning rate experiment and collect Means and SDs.
%
%	Target is a predicate indicator, the symbol and arity of the
%	learning target. This should be alignment/2 for the detect-evil
%	experiment.
%
%	Metric is an atom, the metric to be measured: err, acc, fpr,
%	etc.
%
%	Steps is an integer, the number of steps the experiment will run
%	for.
%
%	Noise is a list of floating point numbers, from 0.0 to 1.0, the
%	amount of classification noise to be added to the positive
%	examples. In each step of the experiment, a learning attempt is
%	made for each noise amount in Noise.
%
%	Means is a list of length equal to Noise where each element is
%	the mean value of the selected Metric for each Noise amount at
%	the same position in Noise.
%
%	SDs is a list of length equal to Noise storing the standard
%	deviations of the reasults averaged in Means.
%
%	Example query
%	=============
%
%	The following uses noise_intervals/4 to generate a list of
%	noise amounts:
%	==
%	?- _T = alignment/2, _M = fnr, _K = 10
%	,detect_evil:noise_interval(1,10,1,_Ps)
%	,detect_evil:learning_rates(_T,_M,_K,_Ps,_Ms,_SDs).
%	==
%
%	The above query will run a learning rate experiment with _K = 10
%	steps, and with noise amounts in the list [0.0,0.1,...,0.9]. The
%	result will be a list of the means and standard deviations of
%	the False Negative Rate metric with each noise amount, in each
%	step. The results will be logged to the log file for the
%	detect-evil experiment, saved in logs/heroes. The name of the
%	log file will start with "detect_evil_" and continue with a
%	timestamp, to easily tell experiments apart. In the log file,
%	the program learned in each step and its accuracy will be logged
%	and at the end of the experiment, R vectors for the mean and SDs
%	of the results will be logged, for use in plotting the results
%	with R.
%
learning_rates(T,M,K,Ps,Ms,SDs):-
	configuration:learner(L)
	,sample_size(S)
	,time_limit(TL)
	,start_logging(M)
	,log_options(T,M,K,Ps)
	,learning_rate(T,M,K,S,TL,Ps,Rs)
	,Rs \= []
	,pairs_averages(Rs,Ms)
	,pairs_sd(Rs,Ms,SDs)
	% Print R vectors for plotting
	,Ms_v =.. [c|Ms]
	,SDs_v =.. [c|SDs]
	,debug(detect_evil, 'metric <- \'~w\'', [M])
	,debug(detect_evil,'~w.~w.mean <- ~w',[L,M,Ms_v])
	,debug(detect_evil,'~w.~w.sd <- ~w',[L,M,SDs_v])
	,close_log(detect_evil).


%!	learning_rate(+Target,+Metric,+Steps,+Sample,+Limit,+Noise,-Results)
%!	is det.
%
%	Business end of learning_rates/6.
%
%	Limit is the time limit defined in time_limit/1. This is used to
%	limit the time a learning attempt is allowed to continue for.
%
%	Results is a list of lists of length equal to Samples, where
%	each sub-list is the lits of values of the chosen Metric for
%	the corresponding Sample size.
%
learning_rate(T,M,K,S,L,Ps,Rs):-
	findall(Vs
	       ,(between(1,K,J)
		,debug(progress,'Step ~w of ~w',[J,K])
		,findall(P-V
			,(member(P,Ps)
			 ,set_noise_amount(P)
			 ,debug(progress,'Set noise amount to: ~w',[P])
			 ,debug(detect_evil,'Set noise amount to: ~w',[P])
			 ,misclassify
			 % Soft cut to stop Thelma backtracking
			 % into multiple learning steps.
			 ,once(timed_train_and_test(T,S,L,Prog,M,V))
			 ,debug(detect_evil,'Learned program:',[])
			 ,debug_clauses(detect_evil,Prog)
			 ,debug(detect_evil,'With ~w: ~4f~n',[M,V])
			 )
			,Vs)
		)
	       ,Rs).


%!	log_options(+Target,+Metric,+Steps,+Noise) is det.
%
%	Log experiment settings.
%
log_options(T,M,K,Ps):-
	configuration:learner(Lrn)
	,sample_size(S)
	,time_limit(L)
	,experiment_data(T,Pos,Neg,BK,MS)
	,length(Pos, Pos_n)
	,length(Neg, Neg_n)
	,debug(detect_evil,'Experiment settings',[])
	,debug(detect_evil,'Learner: ~w',[Lrn])
	,debug(detect_evil,'Positive examples: ~w',[Pos_n])
	,debug(detect_evil,'Negative examples: ~w',[Neg_n])
	,debug(detect_evil,'Background knowledge: ~w',[BK])
	,debug(detect_evil,'Metarules: ~w',[MS])
	,debug(detect_evil,'Evaluation metric: ~w',[M])
	,debug(detect_evil,'Experiment steps: ~w',[K])
	,debug(detect_evil,'Noise amounts: ~w',[Ps])
	,debug(detect_evil,'Sample size: ~w',[S])
	,debug(detect_evil,'Time limit: ~w~n~n',[L]).


%!	set_noise_amount(+Amount) is det.
%
%	Helper predicate to manipulate noise/1 dynamically.
%
%	Used by learning_rate/6 to set the amount of noise for each
%	learning attempt in a detect-evil learning rate experiment.
%
set_noise_amount(P):-
	retractall(noise(_))
	,assert(noise(P)).


%!	noise_interval(+I,+K,+J,-Sequence) is det.
%
%	Generate a Sequence of floating point numbers.
%
%	Wrapper around mathemancy:interval/4 to multiply integers in a
%	sequence by 0.1 in order to generate a list of floats, rather
%	than integers.
%
%	Sequence is a list of floating point numbers that are the
%	products of the numbers in the closed interval [I,J], increasing
%	with stride K.
%
%	Use this to generate a list of noise amounts for detect-evil
%	learning rate experiments.
%
%	See learning_rates/6 for an example of using noise_interval/4 to
%	generate a sequence of noise amounts for use with
%	learning_rates/6.
%
noise_interval(I,K,J,Ps):-
	interval(I,K,J,Is)
	,maplist(product(0.1),Is,Ps).

%!	product(+A,+B,-C) is det.
%
%	Multiplication predicate for use in maplist/3.
%
product(A,B,C):-
	C_ is A * B
	,format(atom(N),'~2f',[C_])
	,atom_number(N, C).



% [mil_problem]
%===============================================================================
% MIL problem
%===============================================================================

/* % Moved to configuration for compatibility between learners
:-dynamic m/3.
configuration:metarule(double_identity,P,Q,R,Y,Z,D):-m(P,X,Y),m(Q,X,Z),m(R,X,D).
*/

% Background knowledge depends on the attributes selected for the
% auto-generated heroes.pl file, according to hero_attributes/1 in
% heroes_configuration.pl.
background_knowledge(alignment/2, BK):-
	heroes_configuration:hero_attributes(As)
	,findall(A/2
	       ,(member(A, As)
		)
	       ,BK).

metarules(alignment/2,[double_identity]).

positive_example(alignment/2,alignment(Id, evil)):-
	alignment(Id, evil).

negative_example(alignment/2,alignment(Id, evil)):-
	alignment(Id, good).


%!	save_alignments is det.
%
%	Save true alignment to a file.
%
%	This copies all the alignment/2 atoms from the auto-generated
%	dataset in heroes.pl to a file alingment.pl. This keeps them
%	safe from misclassify/0 so they can be restored to their
%	original form later.
%
%	Note that this predicate is called as a directive whenever this
%	file is loaded. The directive is directly below this definition.
%
%	See misclassified/0 for an explanation of how alignments are
%	manipulated dynamically and why restoring them from a static
%	source is well, sort of necessary.
%
save_alignments:-
	(   is_stream(alignment_set)
	->  close(alignment_set)
	;   true
	)
	,findall(alignment(Id,A)
	       ,alignment(Id,A)
	       ,As)
	,open('data/noise/heroes/alignment.pl',write,S,[alias(alignment_set)])
	,format(S,':-module(alignment, []).~n~n',[])
	,format(S,':-dynamic alignment/2.~n~n',[])
	,forall(member(A,As)
	       ,write_term(S,A,[fullstop(true)
			       ,nl(true)
			       ]
			  )
	       )
	,close(S).

% Keep true alignment information safe from misclassify/0.
% See save_alignments/0 and misclassify/0 defined in this file.
%:-save_alignments.

:- (\+ exists_file('data/thelma_louise/noise/heroes/alignment.pl')
   ->  save_alignments
   ;   true
   ).


%!	misclassify is det.
%
%	Add classification noise to positive examples.
%
%	This predicate dynamically manipulates the Herbrand base of
%	alignment/2, i.e. the positive and negative examples of the
%	target predicate for the learning rate experiments defined in
%	the experiment_code section.
%
%	Examples of alingment/2 are atoms of the form alignment(Id,
%	Alignment) where Id is the Id of a hero, and Alignment is one of
%	[good,evil]. alignment/2 atoms where Alignment is "evil" are
%	positive examples for the detect_evil/2 task, whereas atoms
%	where Alignment is "good" are negative examples.
%
%	misclassify/0 adds classification noise only to the _positive_
%	examples of alignment/2. It does this by selecting P _negative_
%	examples, at random and without replacement, and changing their
%	second argument from "good" to "evil", thereby turning them
%	into false positives. The original negative examples are then
%	removed from the set of clauses of alignment/2 in the dynamic
%	database, and the false positives are added in. The amount of
%	noise, P, is taken from noise/1 defined in the
%	experiment_settings section.
%
%	misclassify/0 also ensures that the set of positive and negative
%	examples of alignment/2 are balanced, in the sense that there is
%	an equal number of positive and negatives. This is achieved with
%	a call to balance/5. The purpose of balancing the numbers of two
%	sets of examples is to avoid misleading accuracy measurements
%	when learning fails and the empty hypothesis is returned. The
%	empty hypothesis rejects all negative examples and so has a
%	maximal false positive rate. Although all positive examples are
%	also rejected, therefore the false negative rate is also
%	maximal, when there are many fewer positive than negative
%	examples, the overall rate of misclassifications, measured by
%	the accuracy metric (or its complement, error) is very high.
%
%	Resetting alignments
%	====================
%
%	The dynamic manipulation of the definition of alignment/2, as
%	expected, causes all sorts of headaches. In particular, it
%	complicates the task of "resetting" the definition of
%	alignment/2 between experiments, so that different amounts of
%	noise can be added to the positive examples in different steps
%	of a learning rate experiment.
%
%	For this reason, the original definition of alignment/2, as
%	defined in the auto-generated dataset in heroes.pl, is copied
%	from heroes.pl to a file alignment.pl (in the same directory as
%	this file). This file is loaded at the start of execution of
%	misclassify/0, thereby replacing all alingment/2 atoms with
%	their original definition.
%
%	@tbd The dynamic database is EVIL.
%
misclassify:-
	noise(P)
	,use_module(data(noise/heroes/alignment))
	,findall(alignment(Id,evil)
	       ,alignment:alignment(Id,evil)
	       ,Pos)
	,findall(alignment(Id,good)
	       ,alignment:alignment(Id,good)
	       ,Neg)
	,(   P =:= 0
	 ->  Replaced = []
	    ,True_Pos = Pos
	 ;   p_list_partitions(P,Pos,Replaced,True_Pos)
	 )
	,length(Replaced,K)
	,misclassified(K,Neg,good/evil,False_Pos,True_Neg)
	,balance(True_Pos,True_Neg,False_Pos,Pos_,Neg_)
	,flatten([Pos_,Neg_],Es)
	,retractall(heroes:alignment(_,_))
	,forall(member(E,Es)
	       ,assert(heroes:E)
	       ).


%!	misclassified(+K,+Examples,+Signs,-False,-True) is det.
%
%	Misclassify a partition of K elements of a set of Examples.
%
%	Examples is a list of examples of alignment/2. In particular,
%	it's the set of alignment/2 atoms read from the file
%	alignment.pl that stores the "true" alignments in heroes.pl.
%
%	K is an integer, the number of Examples that are to be
%	misclassified.
%
%	Signs is a term T/F, where T the "true" alignment that must be
%	changed and F the false alignment to which T must be changed.
%	For the purpose of misclassifying positive examples of the
%	detect_evil/2 task, T/F is good/evil, resulting in the change of
%	"good" to "evil" in the second argument of some alignment/2
%	atoms in Examples.
%
%	misclassified/4 splits Examples into two partitions, False and
%	True. False holds a proportion of atoms in Examples equal to P,
%	where P is taken from the argument of noise/1 (defined in
%	section experiment_settings). True holds the remaining atoms.
%
%	Each of the elements of False is misclassified by "flipping" its
%	alignment term, from T to F. In particular, for the purpose of
%	misclassifying negative examples of the detect_evil/2 task as
%	positive, an atom alignment(Id, T) in Examples is replaced by an
%	atom alignment(Id, F) in False, where T is "good" and F is
%	"evil".
%
misclassified(_,Es,_,[],Es):-
	noise(P)
	,P =:= 0
	,!.
misclassified(K,Es,T/F,False,True):-
	k_list_partitions(K,Es,False_,True)
	,findall(alignment(Id,F)
		,(member(alignment(Id,T),False_)
		 %,format('Misclassifying ~w~n',[Id])
		 )
		,False).


%!	balance(+Pos,+Neg,-False_Positive,-True_Positive,-True_Negative)
%!	is det.
%
%	Balance the numbers of a set of positive and negative examples.
%
%	Pos and Neg are lists of true positive and negative examples.
%
%	False_Positive is a list of false positives, produced by
%	misclassified/5. True_Positive is the concatenation of Pos and
%	False_Positive. True_Negative is a list of elements of Neg of
%	length equal to True_Positive and with elements selected at
%	random and without replacement.
%
%	In short, this predicate ensures that the sets of positive and
%	negative examples of alingment/2 are of equal length, while
%	including false positive "noise" to the set of positives.
%
balance(Pos,Neg,False_Pos,Pos_,Neg_):-
	append(Pos,False_Pos,Pos_)
	,length(Pos_,K)
	,k_list_samples(K,Neg,Neg_).



% Target theory, also used to generate alignments in hero_generator.
% Named true_alignment/2 to avoid trouble with dynamic manipulation of
% alignment/2 in misclassify/0.
true_alignment(Id,evil):- class(Id, knight), honour(Id, dishonourable).
true_alignment(Id,evil):- class(Id, raider), kills(Id, scourge).
true_alignment(Id,evil):- class(Id, priest), faith(Id, faithless).


% [auxiliary_preds]
%===============================================================================
% Auxiliary predicates
%===============================================================================


%!	hero_attributes(?Id, ?Hero) is nondet.
%
%	A Heroe's attributes.
%
%	Hero is an atom hero/N, where N the number of hero attributes
%	declared in heroes_configuration.pl, as hero_attributes/1.
%
%	Used to debug learned hypotheses and the MIL problem.
%
hero_attributes(Id,H):-
       heroes_configuration:hero_attributes([A|As])
       ,functor(Attr_1,A,2)
       ,Attr_1 =.. [A,Id,V]
       ,call(Attr_1)
       ,findall(V_
	       ,(member(A_, As)
		,functor(Attr,A_,2)
		,Attr =.. [A_,Id,V_]
		,call(Attr)
		)
	       ,Vs)
       ,length(As,N)
       ,N_ is N + 2 % id and value of first attr.
       ,functor(H, hero, N_)
       ,H =.. [hero,Id,V|Vs].