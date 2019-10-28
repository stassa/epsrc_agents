:-module(louise, [learn/1
		 ,learn/2
		 ,learn/5
		 ,top_program/5
		 ,reduced_top_program/5
		 ,selected_subhypothesis/5
		 ]).

:-use_module(configuration).
:-use_module(src(auxiliaries)).
:-use_module(src(mil_problem)).
:-use_module(lib(tp/tp)).

/** <module> Meta-Interpretive Learning by Top program construction and reduction.

*/

%!	learn(+Target) is det.
%
%	Learn a deafinition of a Target predicate.
%
learn(T):-
	learn(T,Ps)
	,print_clauses(Ps).



%!	learn(+Target,-Definition) is det.
%
%	Learn a definition of a Target predicate.
%
learn(T,Ps):-
	tp_safe_experiment_data(T,Pos,Neg,BK,MS)
	,learn(Pos,Neg,BK,MS,Ps).



%!	learn(+Pos,+Neg,+BK,+Metarules,-Progam) is det.
%
%	Learn a Progam from a MIL problem.
%
learn(Pos,Neg,BK,MS,Ps):-
	debug(learn,'Encapsulating problem',[])
	,encapsulated_problem(Pos,Neg,BK,MS,[Pos_,Neg_,BK_,MS_])
	,debug(learn,'Constructing Top program',[])
	,top_program(Pos_,Neg_,BK_,MS_,Ms)
	,debug(learn,'Reducing Top program',[])
	,reduced_top_program(Pos_,BK_,MS_,Ms,Rs)
	,examples_target(Pos,T)
	,debug(learn,'Excapsulating problem',[])
	,excapsulated_clauses(T,Rs,Ps).



%!	top_program(+Pos,+Neg,+BK,+Metarules,-Top) is det.
%
%	Construct the Top program for a MIL problem.
%
%	Clauses are selected according to the configuration setting
%	theorem_prover/1.
%
%	If theorem_prover/1 is set to "resolution", Top program
%	construction is performed in a top-down manner using SLD
%	resolution to decide entailment, which is faster (because it
%	hands off to the Prolog interpreter), but not guaranteed to
%	terminate (for example, it may go infinite given the
%	left-recursive nature of encapsulated metarules).
%
%	If the value of theorem_prover/1 is "tp", Top program
%	construction is performed in a bottom-up manner, using a TP
%	operator. This is slower (because it's implemented in Prolog)
%	but it's guaranteed to terminate. Note also that the TP operator
%	only works for datalog definite programs.
%
%	@bug Top program specialisation using the TP operator is still a
%	work in progress and may not fully eliminate too-general
%	metasubstitutions.
%
%	@bug Actually, Top program construction using the TP operator
%	currently doesn't work at all.
%
top_program(Pos,Neg,BK,MS,Ts):-
	configuration:theorem_prover(resolution)
	,!
	,write_program(Pos,BK,Refs)
	,top_program_(Pos,Neg,BK,MS,Ms)
	,constraints(Ms, Ms_)
	,unfolded_metasubs(Ms_,MS,Ts)
	,erase_program_clauses(Refs).
top_program(Pos,Neg,BK,MS,Ts):-
	configuration:theorem_prover(tp)
	,examples_target(Pos,T)
	,bind_target(MS,T,MS_)
	,flatten([Pos,BK],Ps)
	,generalise(MS_,Ps,Is,Ts_Pos)
	,unfolded_metasubs(Ts_Pos,MS,Ts_Pos_)
	,specialise(Ts_Pos_,Is,Neg,Ts).


%!	write_program(+Pos,+BK,+PS,-Refs) is det.
%
%	Write an encapsulated MIL problem to the dynamic database.
%
%	@tbd The negative examples and metarules don't need to be
%	written to the dynamic database.
%
write_program(Pos,BK,Rs):-
	findall(Rs_i
		,(member(P, [Pos,BK])
		 ,assert_program(user,P,Rs_i)
		 )
		,Rs_)
	,flatten(Rs_,Rs).


%!	top_program(+Positive,+Negative,+BK,+Metarules,-Metasubstitutions)
%!	is det.
%
%	Collect all correct Metasubstitutions in a MIL problem.
%
top_program_(Pos,Neg,_BK,MS,Ss):-
	generalise(Pos,MS,Ss_Pos)
	,specialise(Ss_Pos,Neg,Ss).


%!	generalise(+Positive,+Metarules,-Generalised) is det.
%
%	Generalisation step of Top program construction.
%
%	Generalises a set of Positive examples by finding each
%	metasubstitution of a metarule that entails a positive example.
%
%	Generalised is a set of key-value pairs where the keys are
%	ground metasubstitution atoms and the values are a copy with
%	free variables of the encapsulated head and body literals of the
%	metarule corresponding to the metasubsitution.
%
generalise(Pos,MS,Ss_Pos):-
	setof(H-M
	     ,M^MS^M_^Ep^Pos^
	      (member(M,MS)
	      ,copy_term(M,M_)
	      ,member(Ep,Pos)
	      ,metasubstitution(Ep,M_,H)
	      )
	     ,Ss_Pos).


/* Alternative version- only resolves metarules, without taking into
%  account the examples except to bind the symbol of the target predicate.
%  This one is a tiny bit faster but the one above is currently the one
%  in the technical report on Louise.

generalise(Pos,MS,Ss_Pos):-
	Pos = [E|_Es]
	,E =.. [m,T|_As]
	,setof(M
	     ,M^B^MS^N^T^Ps^
	       (member(M:-B,MS)
		     ,M =.. [m,N,T|Ps]
		     ,call(M)
		     )
	     ,Ss_Pos).
*/


%!	specialise(+Generalised,+Negatives,-Specialised) is det.
%
%	Specialisation step of Top program construction.
%
%	Specialises a set of metasubstitutions generalising the positive
%	examples against the Negative examples by discarding each
%	metasubstitution that entails a negative example.
%
specialise(Ss_Pos,Neg,Ss_Neg):-
	setof(H
	     ,H^M^Ss_Pos^En^Neg^
	      (member(H-M,Ss_Pos)
	      ,\+((member(:-En,Neg)
		  ,metasubstitution(En,M,H)
		  )
		 )
	      )
	     ,Ss_Neg).


%!	metasubstitution(+Example,+Metarule,-Metasubstitution) is
%!	nondet.
%
%	Perform one Metasubstutition of Metarule initialised to Example.
%
%	Example is either a positive example or a negative example. A
%	positive example is a ground definite unit clause, while a
%	negative example is a ground definite goal (i.e. a clause of the
%	form :-Example).
%
metasubstitution(E,M,Sub):-
	bind_head_literal(E,M,(Sub:-(E,Ls)))
	,user:call(Ls).


%!	bind_head_literal(+Example,+Metarule,-Head) is det.
%
%	Bind an Example to the encapsulated Head literal of a Metarule.
%
%	Abstracts the complex patterns of binding examples to the heads
%	of metarules with and without body literals.
%
bind_head_literal(E,M,(H:-(E,Ls))):-
	M = (H:-(E,Ls))
	,!.
bind_head_literal(E,M,(H:-(E,true))):-
	M = (H:-E).


%!	bind_target(+Metarules,+Target,-Bound) is det.
%
%	Bind the Target's symbol to the heads of Metarules.
%
%	Small optimisation to ensure that lefp/2 only considers
%	metasubstitutions where the target predicate is the first
%	predicate symbol, rather than all possible metasubstitutions.
%
bind_target(MS,T/_A,MS_):-
	findall(H:-B
	       ,(member(H:-B, MS)
		,H =.. [m,_Id,T|_Ps]
		)
	       ,MS_).


%!	generalise(+Metarules,+Program,-Model,-Generalised) is
%!	det.
%
%	Top program generalisation step with TP operator.
%
%	Metarules is the set of metarules in the problem, expanded and
%	with the first predicate symbol in their head bound to the
%	symbol of the target predicate, as returned by bind_target/3.
%
%	Program is a flat list of the encapsulation of the positive
%	examples and background knowledge.
%
%	Model is the least Herbrand model of Program. This is passed to
%	specialise/4 to avoid duplicating work (specifically, the work
%	of building this one up again).
%
%	@tbd This is just a thin wrapper around lfp_query/4 now. Still,
%	keep it around - makes it clear this is a distinct step in the
%	construction of the Top program.
%
generalise(MS,Ps,Is,Ts_Pos):-
	lfp_query(MS,Ps,Is,Ts_Pos)
	%,writeln('Top program - generalise:')
	%,print_clauses(Ts_Pos)
	%,nl
	%,writeln('Top program - Interpretation')
	%,print_clauses(Is)
	%,nl
	.


%!	specialise(+Generalised,+Model,+Negatives,-Specialised) is
%!	det.
%
%	Top program specialisation step with TP operator.
%
%	Generalised is the result of generalise/4. Model is the least
%	Herbrand model of the positive examples and background
%	knowledge, calculated during execution of generalise/4.
%
specialise(Ts_Pos,Ps,Neg,Ts_Neg):-
	findall(H:-B
		,(member(H:-B,Ts_Pos)
		 ,lfp_query([H:-B],Ps,As)
		 ,ord_intersection(As, Neg, [])
		 )
		,Ts_Neg)
	%,writeln('Top program - specialise:')
	%,print_clauses(Ts_Neg)
	%,nl
	.


%!	constraints(+Top,-Filtered) is det.
%
%	Filter the Top program by a set of metarule constraints.
%
%	Constraints are declared in experiment files as clauses
%	of configuration:metarule_constraints/2.
%
%	The first argument of metarule_constraints/2 is the
%	metasubstitution atom of an encapsulated metarule (the functor
%	must be "metarule" not "m"). Metarule constraints are applied to
%	any metasubstitution in the Top program that match this first
%	argument.
%
%	The second argument of metarule_constraints/2 is an arbitrary
%	Prolog goal. If the goal fails, the metasubstitution in the
%	first argument is removed from the Top program.
%
%	@tbd If there are any metarule constraints declared in the
%	current experiment file, this predicate will walk over the
%	entire Top program to filter it. It would save quite a bit of
%	juice to instead do the check at the point where a
%	metasubstitution is initially created- for example, right after
%	metasubstitution/3.
%
constraints(Ms,Ms):-
	predicate_property(metarule_constraints(_,_), number_of_clauses(0))
	,!.
constraints(Ms,Ms_):-
	predicate_property(metarule_constraints(_,_), number_of_clauses(N))
	,N > 0
	,findall(Sub
		,(member(Sub,Ms)
		 ,Sub =.. [m|As]
		 ,Sub_ =.. [metarule|As]
		 ,configuration:metarule_constraints(Sub_, C)
		 ,user:call(C)
		 )
		,Ms_).



%!	reduced_top_program(+Pos,+BK,+Metarules,+Program,-Reduced)
%!	is det.
%
%	Reduce the Top Program.
%
%	Clauses are selected according to the value of the configuration
%	option recursive_reduction/1. If this is set to true, the Top
%	program is reduced recursively, by passing the output of each
%	reduction step to the next, as input. If recursive_reduction/1
%	is set to false a single reduction step is performed.
%
%	Recursive reduction is useful when the Top program is large, or
%	recursive, and a large number of resolution steps are required
%	to reduce it effectively. In such cases, recursive reduction can
%	result in a stronger reduction of the Top program (i.e. result
%	in fewer redundant clauses in the learned hypothesis) in a
%	shorter amount of time, without increasing the number of
%	resolution steps in the program reduction meta-interpreter.
%
reduced_top_program(Pos,BK,_MS,Ps,Rs):-
	configuration:reduction(subhypothesis)
	,!
	,write_program(Pos,BK,Refs)
	,subhypothesis(Pos,Ps,Rs)
	,erase_program_clauses(Refs).
reduced_top_program(Pos,BK,MS,Ps,Rs):-
	configuration:recursive_reduction(true)
	,!
	,flatten([Pos,BK,Ps,MS],Fs_)
	,program_reduction(Fs_,Rs_,_)
	,length(Fs_,M)
	,length(Rs_,N)
	,debug(reduction,'Initial reduction: ~w to ~w',[M,N])
	,reduced_top_program_(N,Rs_,BK,MS,Rs)
	% program_reduction module leaves behind garbage
	% in program module. Why?
	,cleanup_experiment.
reduced_top_program(Pos,BK,MS,Ps,Rs):-
	configuration:recursive_reduction(false)
	,flatten([Pos,BK,Ps,MS],Fs_)
	,program_reduction(Fs_,Rs,_)
	,cleanup_experiment.


%!	reduced_top_program_(+N,+Prog,+BK,+Metarules,-Reduced) is
%!	det.
%
%	Business end of reduced_top_program/6
%
%	Recursively reduces the Top Program, by feeding back the result
%	of each call to program_reduction/2 to itself, a process known
%	as "doing feedbacksies".
%
reduced_top_program_(N,Ps,BK,MS,Bind):-
	program_reduction(Ps,Rs,_)
	,length(Rs, M)
	,debug(reduction,'New reduction: ~w to ~w',[N,M])
	,M < N
	,!
	,reduced_top_program_(M,Rs,BK,MS,Bind).
reduced_top_program_(_,Rs,_BK,_MS,Rs).



%!	selected_subhypothesis(+Pos,+BK,+MS,+Prog,-Sub) is det.
%
%	Select a correct sub-hypothesis from a set of clauses.
%
%	@tbd Needs documentation.
%
selected_subhypothesis(Pos,BK,MS,Ps,Hs):-
	encapsulated_problem(Pos,[],BK,MS,[Pos_,[],BK_,_MS_])
	,encapsulated_clauses(Ps, Ps_)
	% Why do we need to write the positiv examples?
	,write_program(Pos_,BK_,Refs)
	,subhypothesis(Pos_,Ps_,Hs_)
	,erase_program_clauses(Refs)
	,examples_target(Pos_,T)
	,excapsulated_clauses(T,Hs_,Hs).


%!	subhypothesis(+Positive,+Top,-Subhypothesis) is det.
%
%	Select a subset of clauses of the Top program.
%
%	Subhypothesis is a sub-set of the clauses in the Top program
%	that entails each positive example (and none of the negatives).
%
subhypothesis(Pos,Ps,Hs):-
	sort(Ps, Ps_s)
	,ord_subtract(Ps_s,Pos,Ps_r)
	,random_permutation(Ps_r, Ps_)
	,subhypothesis(Ps_, Pos, [], [], Hs).

%!	subhypothesis(+Overhypothesis,+Positives,+Entailed,+Acc,-Subhypothesis)
%!	is det.
%
%	Business end of subhypothesis/3.
%
%	Positives is the set of positive training examples. Entailed is
%	the accumulator of examples entailed by the Subhypothesis
%	constructed so-far.
%
%	@tbd This needs documentation of the algorithm implemented.
%
subhypothesis(_,[],_,Acc,Hs):-
	reverse(Acc,Hs)
	,!.
subhypothesis([],_,_Ps,Acc,Hs):-
% This should not really be allowed. This needs fixin.
	reverse(Acc,Hs)
	,!.
subhypothesis([C|Ps],Pos,Es,Acc,Bind):-
	tautology(C)
	,!
	,subhypothesis(Ps,Pos,Es,Acc,Bind).
subhypothesis([C|Ps],Pos,Es,Acc,Bind):-
	member(E,Es)
	,entails(C,E)
	,! % Cut member/2 choicepoint
	,subhypothesis(Ps,Pos,Es,Acc,Bind).
subhypothesis([C|Ps], Pos, Es, Acc, Bind):-
	entailed_by(C,Pos,[],Pos_,Es,Es_)
	,Pos_ \= Pos
	,subhypothesis(Ps,Pos_,Es_,[C|Acc],Bind).


%!	entailed_by(+Clause,+Examples,+Acc_1,+Ex_New,+Acc_2,-Entailed)
%!	is det.
%
%	Find all Examples entailed by a Clause.
%
%	Acc_1 is the accumulator of positive examples _not_ entailed by
%	Clause, or any of the clauses in the sub-hypothesis constructed
%	by subhypothesis/5.
%
%	Acc_2 is the accumulator of positive examples entailed so-far by
%	the sub-hypothesis constructed in subhypothesis/5.
%
entailed_by(_C,[],Pos,Pos,Es,Es):-
	!.
entailed_by(C,[E|Pos],Pos_Acc,Pos_Bind,Es_Acc,Es_Bind):-
	entails(C,E)
	,!
	,entailed_by(C,Pos,Pos_Acc,Pos_Bind,[E|Es_Acc],Es_Bind).
entailed_by(C,[E|Pos],Pos_Acc,Pos_Bind,Es_Acc,Es_Bind):-
	entailed_by(C,Pos,[E|Pos_Acc],Pos_Bind,Es_Acc,Es_Bind).


%!	entails(+Clause,+Example) is det.
%
%	True when Clause entails Example.
%
%	Entailment is decided by binding Example to the head of Clause
%	and calling the body of Clause.
%
%	The encapsulated MIL problem is in the dynamic database so if
%	the call succeeds Clause entails Example with respect to the
%	background knowledge in the MIL problem.
%
entails(C,E):-
	C \= E
	,(   copy_term(C,E:-B)
	 ->  user:call(B)
	 ;   C =.. [F|_]
	    ,F \= ':-' %So, a fact
	 ).


%!	tautology(?Clause) is semidet.
%
%	True when Clause is a tautology.
%
%	@tbd Well, this is a bit of a misnomer. This predicate is true
%	when a clause is of the form L:-L, i.e. when it's made up of the
%	same literal as both head and body. True test for tautologies
%	takes a bit more work, I reckon.
%
tautology(C):-
	copy_term(C, H:-B)
	,numbervars(H:-B)
	,H = B.
