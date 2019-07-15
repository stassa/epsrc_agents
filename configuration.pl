:-module(configuration, [derivation_depth/1
			,experiment_file/2
			,extend_metarules/1
			,metarule/2
			,metarule/3
			,metarule/4
			,metarule/5
			,metarule_language/2
			,recursion_depth_limit/2
			,resolutions/1
			]).

:-user:use_module(src(experiment_file)).
:-reexport(lib(program_reduction/reduction_configuration), except([derivation_depth/1
								  ,resolutions/1])).

% Body literals of H(2,2) metarules.
:-dynamic m/1
         ,m/2
         ,m/3
	 ,m/4
	 ,m/5.

:-multifile m/1
           ,m/2
	   ,m/3
	   ,m/4
	   ,m/5.

% Allows experiment files to define their own, special metarules.
% BUG: Actually, this doesn't work- module quantifiers, again.
% Needs fixing.
:-multifile metarule/2
           ,metarule/3
           ,metarule/4
	   ,metarule/5.

/* Debug levels */
%:-debug(depth). % Debug number of clauses and invented predicates.
%:-debug(learn). % Debug learning steps.
%:-debug(top). % Debug Top program construction.
%:-debug(reduction). % Debug Top program construction.
%:-debug(episodic). % Debug episodic learning.


%!	derivation_depth(?Depth) is semidet.
%
%	Maximum depth of derivation branches.
%
%	Used in program_reduction module with solve_to_depth/3 and
%	solve_to_limit/4 meta-interpreters.
%
%derivation_depth(3).
%derivation_depth(5).
%derivation_depth(8).
derivation_depth(9).
%derivation_depth(10).
%derivation_depth(20).
%derivation_depth(5000).


%!	experiment_file(?Path,?Module) is semidet.
%
%	The Path and Module name of an experiment file.
%
experiment_file('data/examples/kinship/tiny_kinship.pl',tiny_kinship).
%experiment_file('data/examples/kinship/my_family_tree.pl',my_family_tree).
%experiment_file('data/examples/kinship/kinship.pl',kinship).
%experiment_file('data/examples/grammars/anbn.pl',anbn).


%!	extend_metarules(?Bool) is semidet.
%
%	Whether to extend the metarules in a MIL problem.
%
extend_metarules(false).


%!	metarule(?Id,?P,?Q) is semidet.
%!	metarule(?Id,?P,?Q,?R) is semidet.
%
%	An encapsulated metarule.
%
%	@tbd This representation does not define constraints. For the
%	time being this doesn't seem to be necessary but a complete
%	representation will need to include constraints.
%
metarule(unit,P):- m(P,_X,_Y).
metarule(projection,P,Q):- m(P,X,X), m(Q,X).
metarule(identity,P,Q):- m(P,X,Y), m(Q,X,Y).
metarule(inverse,P,Q):- m(P,X,Y), m(Q,Y,X).
metarule(chain,P,Q,R):- m(P,X,Y), m(Q,X,Z), m(R,Z,Y).
metarule(tailrec,P,Q,P):- m(P,X,Y), m(Q,X,Z), m(P,Z,Y).
metarule(precon,P,Q,R):- m(P,X,Y), m(Q,X), m(R,X,Y).
metarule(postcon,P,Q,R):- m(P,X,Y), m(Q,X,Y), m(R,Y).
metarule(switch,P,Q,R):- m(P,X,Y), m(Q,X,Z), m(R,Y,Z).


%!	metarule_language(?Min,?Max) is semidet.
%
%	The minimume and maximum number of body literals in metarules.
%
%	Used to constraint the search for metarules in
%	louise:metarule_expansion/2.
%
metarule_language(1,3).


%!	recursion_depth_limit(?Purpose,?Limit) is semidet.
%
%	Recursion depth Limit for the given Purpose.
%
%	Limit is an integer, which is passed as
%	the second argument to call_with_depth_limit/3 in order to
%	limit recursion in the listed Purpose.
%
%	Known purposes are as follows:
%
%	* episodic_learning: Limits recursion during Top program
%	construction in episodic learning.
%
recursion_depth_limit(episodic_learning,100).


%!	resolutions(?Resolutions) is semidet.
%
%	Maximum number of resolutions.
%
%	Used with solve_to_depth/3.
%
%resolutions(5_500_000).
%resolutions(20_500_000).
%resolutions(250_000).
%resolutions(10_000).
resolutions(5000).
%resolutions(1000).
%resolutions(15).

% Loads the current experiment file in the Swi-Prolog IDE when the
% configuration is changed.
%
% It is perfectly safe to remove this directive.
%
%:-experiment_file(P,_)
%  ,edit(P).

% This line ensures the experiment file set in the configuration option
% experiment_file/2 is always updated when the configuration module is
% changed and reloaded. Don't remove it.
%
% DO NOT REMOVE THIS LINE!
:-experiment_file:reload.
