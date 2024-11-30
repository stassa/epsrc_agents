Autonomous agents for EPSRC Surrey-Bath project
===============================================

Prerequisites
-------------

1. Install SWI-Prolog

   https://www.swi-prolog.org/download/stable

2. Install the Basic Simulation

   For virtual environments:

   python -m venv venv
   source venv/bin/activate

   Pip-install the sources:

   pip install git+https://github.com/aoat20/survey-simulation

3. Clone the project from github

   `git clone git@github.com:stassa/epsrc_agents.git`

4. Download the Autonomous Agent Framework project submodule

   `cd <path of newly cloned project>`
   git submodule init
   git submodule update

You know should be good to go.


Quickstart instructions
-----------------------

In a console do the following (check the output to make sure there's no errors):

```
% Start SWI-Prolog
> swipl
Welcome to SWI-Prolog (threaded, 64 bits, version 9.3.10-21-g9712e8e0f)
SWI-Prolog comes with ABSOLUTELY NO WARRANTY. This is free software.
Please run ?- license. for legal details.

For online help and background, visit https://www.swi-prolog.org
For built-in help, use ?- help(Topic). or ?- apropos(Word).

% Load Louise, which will load the Basic Sim Environment.
1 ?- [load_headless].
Global stack limit 1,073,741,824
Table space 2,147,483,648
Global stack limit 2,147,483,648
Table space 2,147,483,648
true.

% Load modules to simplify calls afterward
% Remember not to copy the '2 ?-'
2 ?- use_module(lib/grid_master/src/map_display).
true.

3 ?- use_module(lib/controller_freak/executors).
true.

% Run the agent in the Basic Sim environment.
4 ?- _Ep = 'Episode0', environment_init(_Ep,_Fs,_Q0,_O0,_Gs), executor(_Fs,_Q0,_O0,_Gs,_As,[XY,_Map]), length(_As,N), print_map(tiles,_Map), !.
Overwriting the following parameters:
map_path = c:/users/yegoblynqueenne/documents/prolog/ilp_systems/temp/epsrc_agents/data/bath/model/scripts/python/maps/Map1.png
agent_start = [60.0, 190.0]
C:\Users\YeGoblynQueenne\AppData\Roaming\Python\Python310\site-packages\survey_simulation\sim_classes.py:130: RuntimeWarning: invalid value encountered in double_scalars
  d.append(np.abs(np.cross(p2-p1,
. . . . . . . . . . . . . . . . . ■ ■ ■ ■ ■ ■ □ □ □ □ □ □ . .
. . . . . . . . . . . . . . . . ■ □ □ □ □ □ □ □ E □ □ □ □ □ .
. . ■ ■ ■ ■ ■ ■ ■ ■ . . . . . . ■ □ □ □ □ □ □ □ □ □ □ □ □ □ ■
. ■ □ S □ □ □ □ □ □ ■ ■ ■ ■ ■ ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■
. ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■
. ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■
. ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■ ■ .
■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■ ■ ■ □ □ □ □ □ ■ . .
■ □ □ □ □ □ □ □ □ □ □ □ ■ □ □ □ □ □ □ □ ■ . . ■ □ □ □ □ ■ . .
. ■ □ □ □ □ □ □ □ □ □ ■ ■ □ □ □ □ □ □ □ ■ . . ■ □ □ □ □ ■ . .
. . ■ ■ ■ □ □ □ □ □ □ □ ■ □ □ □ □ □ □ □ □ ■ . ■ □ □ □ □ ■ . .
. . . . . ■ ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■ □ □ □ □ □ □ ■ .
. . . . . . . ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■
. . . . . . . . ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■
. . . . . . . . . ■ ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■ .
. . . . . . . . . . . ■ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ ■ .
. . . . . . . . . . . . ■ □ □ □ □ □ □ □ □ □ ■ ■ ■ ■ ■ ■ ■ . .
. . . . . . . . . . . . . ■ □ □ □ □ □ ■ ■ ■ . . . . . . . . .
. . . . . . . . . . . . . . ■ □ □ ■ ■ . . . . . . . . . . . .
. . . . . . . . . . . . . . . ■ ■ . . . . . . . . . . . . . .
XY = 24/18,
N = 351.
```

This will start the simulation and run the "rook" agent.

When the agent finishes you will see the output above, which is the SLAM map
built by rook as it explores the simulation.

Change agent and map
--------------------

To change the map used in the simulation you need to edit two configuration
files.

Every time you change any configuration file you must reload the project files
with the folllowing Prolog query:

```
?- make.
```

Note that you must enter this command at the Prolog prompt. This is the
SWI-Prolog predicate `make/0`. It is _not_ the C make program for make files.
Don't get confused and do a "make" at the OS console.

### Changing the map file

To change the map used in the simulation, edit the following configuration file:


```
epsrc_agents/data/bath/model/model_configuration.pl
```

Edit that file and change the following option:

```
map(model_root(data/occ_grid_1),400,255,'Map1.png').
```

You can choose one of the commented-out options by un-commenting it. Remember to
comment-out the option you want.

Remember to "make" the SWI-Prolog project again to load the new configuration
options.

### Changing the controller

To change the controller used in the simulation, edit the following file:

```
epsrc_agents/lib/controller_freak/controller_freak_configuration.pl
```

Find the following option (near the top of the file) and edit it:

```
controller(controllers/'rook.pl',rook,t).
```

For example, to use the "cantor" controller, comment-out the option above and
comment-in the following one:

```
controller(controllers/'cantor.pl',cantor,t).
```

Remember to "make" the SWI-Prolog project again to load the new configuration
options.
