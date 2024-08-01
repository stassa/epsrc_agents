:-module(controller_freak, [solver_controller/5
                           ,solver_fsc_problems/3
                           ,solver_fsc_problem/3
                           ,solver_fsc_instance/3
                           ,fsc_instances_tuples/2
                           ,fsc_instance_tuples/2
                           ,generate_tuples/4
                           ,generate_actions_symbols/3
                           ,actions_tuples/2
                           ,execution_trace/5
                           ,execution_trace/6
                           ]).

:-use_module(src(auxiliaries)).
:-use_module(src(mil_problem)).

/** <module> Learn a Finite State Controller from examples of its behaviour.

TODO: add terminal state to learned controllers.

*/


%!      solver_controller(+Symbol,+Behaviours,-Controller,-Actions,-Tuples)
%!      is nondet.
%
%       Learn a Controller from examples of its Behaviour.
%
%       Symbol is the symbol of the controller predicate, as a functor,
%       without arity. Controllers are always dyadic predicates, with
%       predicate indicatory Symbol/2.
%
%       Behaviour is a list of controller instances, i.e. atoms of the
%       predicate Symbol/2. Those are either generated by a solver, or
%       by some other means, e.g. a user's input.
%
%       Controller is the list of clauses of the learned controller.
%
%       Example of learning a controller from a training instance
%       generated by a learned solver. The solver experiment file is
%       loaded and exports test_initialisation/4 and
%       solver_test_instance/3, used to generate the training instance
%       for the controller. The controller is learned from this training
%       instance by the query to solver_controller/4. Whitespace is
%       manually added to the query to make it easier to read.
%
%       ==
%       ?- _Id = tessera_1
%       ,_K = 10
%       ,_J = 20
%       ,_M = experiment_file
%       ,_M:test_initialisation(_Id,q0,_Q1,_Ss)
%       ,once((_M:solver_test_instance(s/2,_E,[_Id,_K,_J|_Ss]), _M:_E))
%       ,solver_controller(c,_E,_Cs,_As,_Ts)
%       ,maplist(print_clauses,['% Controller:','% Actions:','% Tuples:'],[_Cs,_As,_Ts]).
%       % Controller:
%       c(A,B):-t198(A,B).
%       c(A,B):-t112(A,C),c(C,B).
%       c(A,B):-t123(A,C),c(C,B).
%       c(A,B):-t141(A,C),c(C,B).
%       c(A,B):-t169(A,C),c(C,B).
%       c(A,B):-t198(A,C),c(C,B).
%       c(A,B):-t37(A,C),c(C,B).
%       c(A,B):-t43(A,C),c(C,B).
%       c(A,B):-t8(A,C),c(C,B).
%       c(A,B):-t83(A,C),c(C,B).
%       % Actions:
%       t112([[q1|A],[upup|B],[right|C],[q1|D]],[A,B,C,D]).
%       t123([[q1|A],[pupp|B],[down|C],[q2|D]],[A,B,C,D]).
%       t141([[q1|A],[uupp|B],[down|C],[q2|D]],[A,B,C,D]).
%       t169([[q2|A],[ppup|B],[right|C],[q1|D]],[A,B,C,D]).
%       t198([[q2|A],[pupu|B],[down|C],[q2|D]],[A,B,C,D]).
%       t37([[q0|A],[uppu|B],[right|C],[q1|D]],[A,B,C,D]).
%       t43([[q0|A],[upuu|B],[right|C],[q1|D]],[A,B,C,D]).
%       t8([[q0|A],[pupu|B],[up|C],[q0|D]],[A,B,C,D]).
%       t83([[q1|A],[puup|B],[up|C],[q0|D]],[A,B,C,D]).
%       % Tuples:
%       t112(q1,upup,right,q1).
%       t123(q1,pupp,down,q2).
%       t141(q1,uupp,down,q2).
%       t169(q2,ppup,right,q1).
%       t198(q2,pupu,down,q2).
%       t37(q0,uppu,right,q1).
%       t43(q0,upuu,right,q1).
%       t8(q0,pupu,up,q0).
%       t83(q1,puup,up,q0).
%       true ;
%       false.
%       ==
%
%       @tbd Te controller actions and tuples returned by this predicate
%       are numbered, while executor predicates defined in this module
%       expect un-numbered tuples. This has to be managed outside this
%       predicate, by whatever process creates the controller file.
%       Like, I dunno, copy-pasting into vim and back?
%
solver_controller(S,Es,[C_t|Cs],[A_t|Bs],Ts):-
        configuration:clause_limit(L)
	,configuration:fetch_clauses(F)
	,configuration:table_meta_interpreter(B)
	,configuration:untable_meta_interpreter(U)
	,solver_fsc_problems(S,Es,[Ss,Is,As,_Ts])
	,max_sequence_length(Is,K)
        ,St = (assert_program(user,As,Rs)
              ,set_configs(K)
              )
        ,Gl = (learning_query(Is,[],Ss,[identity,tailrec],Cs)
              ,controller_actions_tuples(user,Cs,Bs,Ts)
              )
        ,Cl = (erase_program_clauses(Rs)
              ,reset_configs(L,F,B,U)
              )
        ,setup_call_cleanup(St,Gl,Cl)
        % Terminal clause and action allow single-step decision.
        ,C_t = ( c(S1,S2):-terminal(S1,S2) )
        ,A_t = terminal([[],[],[],[]],[[],[],[],[]]).


%!      max_sequence_length(+Instances,-Length) is det.
%
%       Count the observations in a list of Instances of FSC behaviour.
%
max_sequence_length(Is,K):-
        C = c(0)
        ,forall(member(I,Is)
               ,(instance_sequence_length(I,N)
                ,arg(1,C,M)
                ,Max is max(M,N)
                ,nb_setarg(1,C,Max)
                )
               )
        ,arg(1,C,K).


%!	instance_sequence_length(+Instance,-Length) is det.
%
%	Count the Observations in an Instance of an FSC behaviour.
%
instance_sequence_length(I,N):-
	I =.. [_T,[_Q0s,Os,_As,_Q1s],[[],[],[],[]]]
	,length(Os,N)
	,debug(seq_length,'Instance sequence length: ~w',[N]).


%!      set_configs(+Clause_limit) is det.
%
%       Set configuration options for FSC learning.
%
%       Clause_limit is the value of clause_limit/1 to be set. This is
%       equal to the length of the sequences of actions etc. in a
%       controller's training instance.
%
set_configs(K):-
        set_configuration_option(clause_limit,[K])
        ,set_configuration_option(fetch_clauses,[[builtins,bk,metarules]])
        ,set_configuration_option(table_meta_interpreter,[false])
        ,set_configuration_option(untable_meta_interpreter,[true]).


%!      reset_configs(+Limit,+Fetch,+Table,+Untable) is det.
%
%       Reset configuration options to initial values.
%
%       The "initial values" are the values of configuration options
%       before their setting by a call to set_config/1.
%
%       Limit, Fetch, Table and Untable are the initial values of the
%       configuration options clause_limit/1, fetch_clauses/1,
%       table_meta_interpreter/1 and untable_meta_interpreter/1,
%       respectively, retrieved from the configuration before the call
%       to set_config/1. This predicate resets these options to the
%       received values.
%
reset_configs(L,F,B,U):-
        set_configuration_option(clause_limit,[L])
        ,set_configuration_option(fetch_clauses,[F])
        ,set_configuration_option(table_meta_interpreter,[B])
        ,set_configuration_option(untable_meta_interpreter,[U]).


%!      controller_actions_tuples(+Module,+Controller,-Actions,-Tuples)
%!      is det.
%
%       Collect Actions and generate Tuples of a Controller.
%
%       Module is the name of the Prolog module where the Controller's
%       actions are defined, possibly along with controller actions not
%       used by Controller.
%
%       Controller is a list of clauses of the controller whose
%       actions we want to collect.
%
%       Actions is the list of clauses of the controller actions in
%       Module, restricted to the actions used by the Controller,
%       excluding any other controller actions in the same Module.
%
%       Tuples is the set of controller tuples corresponding to the
%       returned Actions.
%
controller_actions_tuples(M,Cs,As,Ts):-
        Cs = [H:-_|_]
        ,functor(H,F,A)
        ,program_symbols(Cs,Ss)
        ,selectchk(F/A,Ss,Ss_)
        ,program(Ss_,M,As)
        ,actions_tuples(As,Ts).



%!      solver_fsc_problems(+Symbol,+Solveds,-Problem) is det.
%
%       Construct a MIL Problem from a list of Solved examples.
%
%       Symbol is the symbol of the controller to be learned.
%
%       As solver_fsc_problem/3 but accepts a list of solved examples
%       to generate an FSC learning problem from all of them.
%
solver_fsc_problems(S,Es,[Ss,Is,As,Ts]):-
        must_be(list,Es)
        ,maplist(solver_fsc_instance(S),Es,Is)
        ,fsc_instances_tuples(Is,Ts)
        ,generate_actions_symbols(Ts,As,Ss).



%!      solver_fsc_problem(+Symbol,+Solved,-Problem) is det.
%
%       Construct a MIL Problem from a Solved example.
%
%       Symbol is the symbol of the controller to be learned.
%
solver_fsc_problem(S,E,[Ss,I,As,Ts]):-
        solver_fsc_instance(S,E,I)
        ,fsc_instance_tuples(I,Ts)
        ,generate_actions_symbols(Ts,As,Ss).



%!      solver_fsc_instance(+Symbol,+Solved,-Instance) is det.
%
%       Create a training instance of an FSC from a solver's result.
%
solver_fsc_instance(S,E,I):-
        E =.. [_,S1,_S2]
        ,reverse(S1,[Q1s,As,Os,Q0s|_])
        ,controller_instance(I,S,Q0s,Os,As,Q1s).



%!      fsc_instances_tuples(+Instances,-Tuples) is det.
%
%       Generate controller Tuples from a list of controller Instances.
%
%       As fsc_instance_tuples/2 but Instances is a list of controller
%       instances rather than a single instance.
%
fsc_instances_tuples(Is,Ts):-
        findall(Qs_i-Os_i-As_i
               ,(member(I,Is)
                ,controller_instance(I,_S,Q0s_i,Os_i,As_i,Q1s_i)
                ,flatten([Q0s_i,Q1s_i],Qs_i)
                )
               ,Qs_Os_As)
        % Lots of complicated mappings.
        ,pairs_keys_values(Qs_Os_As,Qs_Os,As)
        ,pairs_keys_values(Qs_Os,Qs,Os)
        ,maplist(flatten,[Qs,Os,As],[Qs_f,Os_f,As_f])
        ,maplist(sort,[Qs_f,Os_f,As_f],[Qs_s,Os_s,As_s])
        ,generate_tuples(Qs_s,Os_s,As_s,Ts).



%!      fsc_instance_tuples(+Instance,-Tuples) is det.
%
%       Generate controller Tuples from a controller Instance.
%
%       Observations and actions labels are extracted from the lists of
%       observations and actions in Instance.
%
fsc_instance_tuples(I,Ts):-
        controller_instance(I,_S,Q0s,Os,As,Q1s)
        ,flatten([Q0s,Q1s],Qs)
        ,maplist(sort,[Qs,Os,As],[Qs_s,Os_s,As_s])
        ,generate_tuples(Qs_s,Os_s,As_s,Ts).


%!      controller_instance(+Instance,?Symbol,?Qs,?Os,?As,?Us) is det.
%
%       Construct, or deconstruct, a controller Instance.
%
controller_instance(I,S,Q0s,Os,As,Q1s):-
        I =.. [S,[Q0s,Os,As,Q1s],[[],[],[],[]]].



%!	generate_tuples(+States,+Observations,+Actions,-Tuples) is det.
%
%	Generate the set of all tuples of a state transition relation.
%
%	States is a list of Prolog atoms (constants) representing state
%	labels, or names, of states of a Finite State Controller (FSC).
%
%	Observations is a set of constants representing observations
%	that are possible to make in an environment.
%
%	Actions is a set of constants representing actions that are
%	possible for an agent to take in that environment.
%
%	Tuples is a set of four-tuples Tn(S1,O,A,S2), where S1 and S2
%	are two state names in States, O is an obseration in
%	Observations and A is an action in Actions. Tn is an identifier
%	of the tuple, indexing the order of generation of the tuple.
%
%	Each tuple Tn(S1,O,A,S2) in Tuples represents one transition of
%	an FSA from state S1 to state S2 (which may be the same state)
%	when observation O is made and action A is taken.
%
%	The tuples generated here are meant as the extensional basis of
%	a set of actions, representing the transitions from one state to
%	another, of an FSC. They are meant to be used in composing, or
%	rather generating, background predicates, but not as BK
%	themselves.
%
generate_tuples(Ss,Os,As,Ts):-
	C = c(0)
	,findall(T
	       ,(member(S1,Ss)
		,member(S2,Ss)
		,member(O,Os)
		,member(A,As)
		,arg(1,C,I)
		,atom_concat(t,I,Ti)
		,T =.. [Ti,S1,O,A,S2]
		,succ(I,J)
		,nb_setarg(1,C,J)
		)
	       ,Ts).



%!	generate_actions_symbols(+Tuples,-Actions,-Symbols) is det.
%
%	Generate a set of controller Actions from a set of Tuples.
%
%	As generate_actions/2 but also returns the Symbols used in
%	Actions so that we know they're in the right order when we
%	declare the symbols as BK.
%
generate_actions_symbols(Ts,Us,Ss):-
	findall(H-Ti/2
	       ,(member(T,Ts)
		,T =.. [Ti,S1,O,A,S2]
		,H =.. [Ti,[[S1|Cs],[O|Os],[A|As],[S2|Ns]],[Cs,Os,As,Ns]]
		)
	       ,Gs)
	,pairs_keys_values(Gs,Us,Ss).



%!      action_tuples(+Actions,-Tuples) is det.
%
%       Extract controller Tuples from a list of controller Actions.
%
actions_tuples(As,Ts):-
        action_tuples(As,Ts,[]).

%!      action_tuples(+Actions,-Tuples,+Acc) is det.
%
%       Business end of action_tuples/2.
%
action_tuples([],Ts,Ts):-
	!.
action_tuples([Ai|As],[T|Acc],Bind):-
	Ai =.. [S,[[Q0|_],[O|_],[A|_],[Q1|_]],[_,_,_,_]]
	,T =.. [S,Q0,O,A,Q1]
	,action_tuples(As,Acc,Bind).



%!	fsc_test_instance(+What,+Εxample,-Instance) is det.
%
%	Create a test Instance to trace a learned FSC's behaviour.
%
%	What is one of [actions, observations], denoting which of the
%	two will be variabilised in the given Example.
%
%       Example is an example of a learned FSC's behaviour with all
%       lists of states, observation and action labels fully ground.
%
%       Instance is the given Example with its list of observations or
%       actions labels variabilisied, depending on the value of What.
%
%       @tbd: use controller_instance/6
%
%       @tbd: consider allowing state labels to be variabilised also.
%
%       @tbd: Must vary according to grid_master_configuration option
%       action_representation/1.
%
fsc_test_instance(actions,E,E_):-
        E =.. [S,S1,S2]
        ,S1 = [Id,_XYs,_Ts,_Q0,Q0s,Os,_As,Q1s]
        ,S1_ = [Id,_XYe,_Te,_Q1,Q0s,Os,_,Q1s]
        ,E_ =.. [S,S1_,S2].
fsc_test_instance(observations,E,E_):-
        E =.. [S,S1,S2]
        ,S1 = [Q0s,_Os,As,Q1s]
        ,S1_ = [Q0s,_,As,Q1s]
        ,E_ =.. [S,S1_,S2].



%!      execution_trace(+What,+Module,+Controller,+Instance,-Trace) is
%!      det.
%
%       Trace the execution of a Controller.
%
%       What is one of: [actions, observations], an option passed to
%       fsc_test_instance/3, denoting whether actions or observations
%       are left as variables to be instantiated during execution.
%
%       Module is the module name of a currently loaded FSC learning
%       experiment file, or some other Prolog module holding the
%       definitions of the controller's actions used to learn
%       Controller.
%
%       Controller is the list of clauses of a controller learned from
%       the experiment file in the named Module.
%
%       Instance is an instance of the learned Controller's behaviour,
%       which may be a positive example taken from the named Module, or
%       not.
%
%       Trace is a list of tuples corresponding to the actions of the
%       learned Controller as it proves Instance, in the order in which
%       those actions were taken.
%
%       Example of use
%       --------------
%
%       In the example below, first a controller is learned from the
%       currently loaded experiment file and its clauses printed out for
%       user inspection. A positive example defined in the same
%       experiment file is then passed to execution_trace/5, along with
%       the name of the experiment_file module and the option "actions".
%       The ground example is printed out for inspection. The option
%       "actions" means that the positive example's action sequence,
%       which is initially ground, will be variabilised so that the
%       learned controller can generate a new sequence of actions from
%       the ground sequence of observations in that example. The trace
%       printed at the end shows the tuples corresponding to the actions
%       taken by the controller, given the ground observation sequence
%       in the example.
%       ==
%       ?- _W = actions
%       ,_T = c/2
%       ,_M = experiment_file
%       ,time(learn(c/2,_Ps))
%       ,length(_Ps,N)
%       ,_M:positive_example(_T,_E)
%       ,execution_trace(_W,_M,_Ps,_E,_Ss)
%       ,maplist(print_clauses,['Controller:','Example:','Trace:'],[_Ps,_E,_Ss]).
%       % 121,819 inferences, 0.016 CPU in 0.017 seconds (91% CPU, 7796416 Lips)
%       Controller:
%       c(A,B):-t198(A,B).
%       c(A,B):-t112(A,C),c(C,B).
%       c(A,B):-t123(A,C),c(C,B).
%       c(A,B):-t141(A,C),c(C,B).
%       c(A,B):-t169(A,C),c(C,B).
%       c(A,B):-t198(A,C),c(C,B).
%       c(A,B):-t37(A,C),c(C,B).
%       c(A,B):-t43(A,C),c(C,B).
%       c(A,B):-t8(A,C),c(C,B).
%       c(A,B):-t83(A,C),c(C,B).
%       Example:
%       c([[q0,q1,q1,q2,q2,q2,q2,q2,q2,q1,q1,q0,q0,q1,q1,q2],[upuu,upup,uupp,pupu,pupu,pupu,pupu,pupu,ppup,upup,puup,pupu,uppu,upup,pupp,pupu],[right,right,down,down,down,down,down,down,right,right,up,up,right,right,down,down],[q1,q1,q2,q2,q2,q2,q2,q2,q1,q1,q0,q0,q1,q1,q2,q2]],[[],[],[],[]]).
%       Trace:
%       t43(q0,upuu,right,q1).
%       t112(q1,upup,right,q1).
%       t141(q1,uupp,down,q2).
%       t198(q2,pupu,down,q2).
%       t198(q2,pupu,down,q2).
%       t198(q2,pupu,down,q2).
%       t198(q2,pupu,down,q2).
%       t198(q2,pupu,down,q2).
%       t169(q2,ppup,right,q1).
%       t112(q1,upup,right,q1).
%       t83(q1,puup,up,q0).
%       t8(q0,pupu,up,q0).
%       t37(q0,uppu,right,q1).
%       t112(q1,upup,right,q1).
%       t123(q1,pupp,down,q2).
%       t198(q2,pupu,down,q2).
%       N = 10 ;
%       false.
%       ==
%
%       @tbd instead of taking the actions from Module I can generate
%       them on the fly from Instance, with a call to
%       fsc_instance_tuples/2 and then generate_actions_symbols/3. Is
%       that a better way to do it? It removes the need for an
%       experiment file with all the data.
%
execution_trace(W,M,Cs,I,Rs):-
        controller_actions_tuples(M,Cs,As,Ts)
        ,execution_trace(W,Cs,As,Ts,I,Rs).



%!      execution_trace(+What,+Controller,+Actions,+Tuples,+Instance,-Trace)
%!      is det.
%
%       Trace the execution of a Controller.
%
%       As execution_trace/5 but expects Actions and Tuples associated
%       with the controller to be passed in as arguments, instead of
%       retrieving them from a module.
%
execution_trace(W,Cs,As,Ts,I,Rs):-
        program_symbols(Ts,Ts_s)
        ,encapsulated_clauses(Ts,Ts_s,Ts_e)
        ,fsc_test_instance(W,I,I_)
        ,S = (assert_program(program,Cs,Rs_c)
             ,assert_program(program,As,Rs_a)
             ,assert_program(program,Ts_e,Rs_t)
             )
        ,G = (execution_trace(I_,program,Rs)
             % I have no idea what this is cutting.
             %,!
             )
        ,C = (erase_program_clauses(Rs_c)
             ,erase_program_clauses(Rs_a)
             ,erase_program_clauses(Rs_t)
             )
        ,setup_call_cleanup(S,G,C).


%!      execution_trace(+Instance,+Module,-Trace) is nondet.
%
%       Call an Instance into a named Module and Trace it.
%
execution_trace(I,M,Ts):-
        call(M:I)
        ,controller_instance(I,_,Q0s,Os,As,Q1s)
        ,execution_trace_(Q0s,Os,As,Q1s,Ts,[]).

%!      execution_trace_(+Q0s,+Os,+As,+Q1s,-Ts,+Acc) is nondet.
%
%       Business end of execution_trace/3.
%
%       @tbd This assumes tuples are asserted into module "program" but
%       that depends on the call to execution_trace/3.
%
execution_trace_([],[],[],[],Ts,Ts):-
        !.
execution_trace_([Q0|Q0s],[O|Os],[A|As],[Q1|Q1s],[T_|Acc],Bind):-
        T =.. [m,S,Q0,O,A,Q1]
        ,call(program:T)
        ,T_ =.. [S,Q0,O,A,Q1]
        ,execution_trace_(Q0s,Os,As,Q1s,Acc,Bind).
