:-module(grid_navigation_controller, [t/4]).

opposite_actions(up-q0,down-q2).
opposite_actions(down-q2,up-q0).
opposite_actions(left-q3,right-q1).
opposite_actions(right-q1,left-q3).

t(q0,upup,right,q1).
t(q0,upuu,right,q1).
t(q0,ppup,up,q0).
t(q0,pppp,down,q2).
t(q0,pppu,down,q2).
t(q0,pupp,down,q2).
t(q0,pupu,down,q2).
t(q0,ppuu,up,q0).
t(q0,uppp,down,q2).
t(q0,uppu,down,q2).
t(q0,uupp,down,q2).
t(q0,uupu,down,q2).
t(q0,pppp,left,q3).
t(q0,ppup,left,q3).
t(q0,pupp,up,q0).
t(q0,pupp,left,q3).
t(q0,puup,left,q3).
t(q0,uppp,left,q3).
t(q0,upup,left,q3).
t(q0,uupp,left,q3).
t(q0,pupu,up,q0).
t(q0,uuup,left,q3).
t(q1,pppp,up,q0).
t(q1,pppu,up,q0).
t(q1,ppup,up,q0).
t(q1,ppuu,up,q0).
t(q1,pupp,up,q0).
t(q1,pupu,up,q0).
t(q1,puup,up,q0).
t(q0,puup,up,q0).
t(q1,puuu,up,q0).
t(q0,pppp,up,q0).
t(q1,pppp,right,q1).
t(q1,pppu,right,q1).
t(q0,puuu,up,q0).
t(q1,ppup,right,q1).
t(q1,ppuu,right,q1).
t(q1,uppp,right,q1).
t(q1,uppu,right,q1).
t(q1,upup,right,q1).
t(q1,upuu,right,q1).
t(q1,pppp,down,q2).
t(q1,pppu,down,q2).
t(q1,pupp,down,q2).
t(q1,pupu,down,q2).
t(q1,uppp,down,q2).
t(q1,uppu,down,q2).
t(q1,uupp,down,q2).
t(q1,uupu,down,q2).
t(q1,pppp,left,q3).
t(q1,ppup,left,q3).
t(q1,pupp,left,q3).
t(q1,puup,left,q3).
t(q1,uppp,left,q3).
t(q1,upup,left,q3).
t(q1,uupp,left,q3).
t(q1,uuup,left,q3).
t(q2,pppp,up,q0).
t(q2,pppu,up,q0).
t(q2,ppup,up,q0).
t(q2,ppuu,up,q0).
t(q2,pupp,up,q0).
t(q2,pupu,up,q0).
t(q2,puup,up,q0).
t(q2,puuu,up,q0).
t(q2,pppp,right,q1).
t(q2,pppu,right,q1).
t(q2,ppup,right,q1).
t(q2,ppuu,right,q1).
t(q2,uppp,right,q1).
t(q2,uppu,right,q1).
t(q2,upup,right,q1).
t(q2,upuu,right,q1).
t(q2,pppp,down,q2).
t(q2,pppu,down,q2).
t(q2,pupp,down,q2).
t(q0,pppp,right,q1).
t(q2,pupu,down,q2).
t(q2,uppp,down,q2).
t(q2,uppu,down,q2).
t(q2,uupp,down,q2).
t(q2,uupu,down,q2).
t(q0,pppu,right,q1).
t(q2,pppp,left,q3).
t(q2,ppup,left,q3).
t(q2,pupp,left,q3).
t(q2,puup,left,q3).
t(q2,uppp,left,q3).
t(q0,pppu,up,q0).
t(q0,ppup,right,q1).
t(q2,upup,left,q3).
t(q2,uupp,left,q3).
t(q2,uuup,left,q3).
t(q3,pppp,up,q0).
t(q3,pppu,up,q0).
t(q3,ppup,up,q0).
t(q3,ppuu,up,q0).
t(q3,pupp,up,q0).
t(q0,ppuu,right,q1).
t(q3,pupu,up,q0).
t(q3,puup,up,q0).
t(q3,puuu,up,q0).
t(q3,pppp,right,q1).
t(q3,pppu,right,q1).
t(q3,ppup,right,q1).
t(q3,ppuu,right,q1).
t(q3,uppp,right,q1).
t(q3,uppu,right,q1).
t(q3,upup,right,q1).
t(q3,upuu,right,q1).
t(q3,pppp,down,q2).
t(q3,pppu,down,q2).
t(q3,pupp,down,q2).
t(q3,pupu,down,q2).
t(q3,uppp,down,q2).
t(q3,uppu,down,q2).
t(q3,uupp,down,q2).
t(q3,uupu,down,q2).
t(q3,pppp,left,q3).
t(q3,ppup,left,q3).
t(q3,pupp,left,q3).
t(q3,puup,left,q3).
t(q3,uppp,left,q3).
t(q0,uppp,right,q1).
t(q3,upup,left,q3).
t(q3,uupp,left,q3).
t(q3,uuup,left,q3).
t(q0,uppu,right,q1).
