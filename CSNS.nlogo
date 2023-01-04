;;Federico Rullo
;;federico.rullo@studio.unibo.it
;;0001026401

extensions [
  table
  rnd
]

globals[
  link-weight
  sorted-turtles
  infinity
]
turtles-own[
  popular?
  popularity-weight
  average-friends
  average-friends-of-friends
  num-friends
  num-friends-squared
  sum-friends-of-friends-squared
  distance-from-other-turtles
  friendliness
]

;;;;;;;;;;;;;;;
;;Game-Theory;;
;;;;;;;;;;;;;;;

to create-links-game
  ask turtles [
    let potential-friends other turtles
    ask potential-friends [
      if friendliness <= [friendliness] of myself
      [create-link-with myself]
    ]
  ]
end

to delete-links-game
  ask turtles[
   let connected-turtles link-neighbors
   ask connected-turtles[
      if friendliness < [friendliness] of myself [
        if random-float 1 < prob-remove-friends [
          ask link-with myself [die]
        ]
      ]
    ]
  ]
end

to go-game
  ask turtles [
    if random-float 1 < 0.1 [
      ifelse popular? ;;set the friendliness for the game-theory model
      [ set friendliness ( (1 - friendliness) + popularity-weight) ];;popular people will be less keen on isolation than normal
      [ set friendliness ( 1 - friendliness) ]
    ]
  ]
  create-links-game
  delete-links-game
  update-average-friends
  update-average-friends-of-friends
  tick
end

;;;;;;;;;;;;;;;
;;Erdos-Renyi;;
;;;;;;;;;;;;;;;

;;setup the model using Erdos
to setup-Erdos
  clear-all
  setup-turtles
  update-links-Erdos
  set sorted-turtles sort turtles
  update-average-friends
  update-average-friends-of-friends
  reset-ticks
end

;;Run Erdos-Renyi model
to go-Erdos
  update-links-Erdos
  update-average-friends
  update-average-friends-of-friends
  tick
end

;;update links between nodes using Erdos-Renyi model
to update-links-Erdos
  ask turtles[
    ifelse popular?[
      ask links with [link-weight < prob-remove-friends + random-float 0.5 ]
      [die]
    ][
      ask links with [link-weight < prob-remove-friends]
      [die]
    ]
  ]
  ;;add new links between nodes with a specified probability
  ask turtles [
    ifelse popular? [
      create-links-with other turtles with [self > myself and random-float 1.0 < ( prob-making-friends + 0.25 )]
      [set link-weight ( ( prob-making-friends + random-float 0.5 ) + random-float 1.0 )]
    ][
      create-links-with other turtles with [self > myself and random-float 1.0 < prob-making-friends]
      [set link-weight ( prob-making-friends + random-float 1.0 )]
    ]
  ]
end



;;;;;;;;;;;;;;;;;;
;;Watts-Strogatz;;
;;;;;;;;;;;;;;;;;;

;;Setup the model to use the Watts-Strogatz
to setup-Watts
  clear-all
  set infinity 999
  setup-turtles-Watts
  setup-initial-connections-small-world
  set sorted-turtles sort turtles
  update-average-friends
  update-average-friends-of-friends
  reset-ticks
end

to go-Watts
  update-links-Watts
  update-average-friends
  update-average-friends-of-friends
  tick
end

;;create and initialize agents for Watts-Strogatz
to setup-turtles-Watts
  set-default-shape turtles "circle"
  create-turtles num-nodes
  layout-circle (sort turtles) (max-pxcor - 1)
  ask turtles [
    set popular? false
    set popularity-weight random-float 0.5
    if random-float 1.0 < prob-being-popular [ set popular? true ]
    ifelse popular? ;;set the friendliness for the game-theory model
    [ set friendliness (random-float 1.0 + popularity-weight) ]
    [ set friendliness random-float 1.0 ]
    set label who
  ]
end

;;Set the initial connectivity of the network for Watts-Strogatz model
to setup-initial-connections
  ask turtles [
    foreach sort turtles [
      create-links-with other turtles with [distance myself < 2]
    ]
  ]
end

to setup-initial-connections-small-world
  let n 0
  while [ n < count turtles ] [
    ; make edges with the next two neighbors
    ; this makes a lattice with average degree of 4
    make-edge turtle n
              turtle ((n + 1) mod count turtles)
              "default"
    ; Make the neighbor's neighbor links curved
    make-edge turtle n
              turtle ((n + 2) mod count turtles)
              "curve"
    set n n + 1
  ]

  ask link 0 (count turtles - 2) [ set shape "curve-a" ]
  ask link 1 (count turtles - 1) [ set shape "curve-a" ]
end

to make-edge [ node-A node-B the-shape ]
  ask node-A [
    create-link-with node-B  [
      set shape the-shape
    ]
  ]
end

;;update links between nodes using Watts-Strogatz model
to update-links-Watts
  if count turtles != num-nodes [ setup-Watts ]

  let connected? false
  while [ not connected? ] [
    ask links [die]
    setup-initial-connections-small-world
    ask turtles [
      ifelse popular?
      [ask links [if (random-float 1) < prob-making-friends + random-float 0.5 [rewire-me]]]
      [ask links [if (random-float 1) < prob-making-friends [rewire-me]]]
    ]
    ifelse find-average-path-length = infinity [set connected? false] [ set connected? true]
  ]
end

to rewire-me ; turtle procedure
  ; node-A remains the same
  let node-A end1
  ; as long as A is not connected to everybody
  if [ count link-neighbors ] of end1 < (count turtles - 1) [
    ; find a node distinct from A and not already a neighbor of "A"
    let node-B one-of turtles with [ (self != node-A) and (not link-neighbor? node-A) ]
    ; wire the new edge
    ask node-A [ create-link-with node-B [ set color cyan ] ]
    die ; remove the old edge
  ]
end

to-report find-average-path-length
  let apl 0

  ; calculate all the path-lengths for each node
  find-path-lengths
  let num-connected-pairs sum [length remove infinity (remove 0 distance-from-other-turtles)] of turtles

  ; In a connected network on N nodes, we should have N(N-1) measurements of distances between pairs.
  ; If there were any "infinity" length paths between nodes, then the network is disconnected.
  ifelse num-connected-pairs != (count turtles * (count turtles - 1)) [
    ; This means the network is not connected, so we report infinity
    set apl infinity
  ][
    set apl (sum [sum distance-from-other-turtles] of turtles) / (num-connected-pairs)
  ]

  report apl
end

to find-path-lengths
  ; reset the distance list
  ask turtles [
    set distance-from-other-turtles []
  ]

  let i 0
  let j 0
  let k 0
  let node1 one-of turtles
  let node2 one-of turtles
  let node-count count turtles

  ; initialize the list of distances
  while [i < node-count] [
    set j 0
    while [ j < node-count ] [
      set node1 turtle i
      set node2 turtle j

      ; zero from a node to itself
      ifelse i = j [
        ask node1 [
          set distance-from-other-turtles lput 0 distance-from-other-turtles
        ]
      ][
        ; 1 from a node to it's neighbor
        ifelse [ link-neighbor? node1 ] of node2 [
          ask node1 [
            set distance-from-other-turtles lput 1 distance-from-other-turtles
          ]
        ][ ; infinite to everyone else
          ask node1 [
            set distance-from-other-turtles lput infinity distance-from-other-turtles
          ]
        ]
      ]
      set j j + 1
    ]
    set i i + 1
  ]
  set i 0
  set j 0
  let dummy 0
  while [k < node-count] [
    set i 0
    while [i < node-count] [
      set j 0
      while [j < node-count] [
        ; alternate path length through kth node
        set dummy ( (item k [distance-from-other-turtles] of turtle i) +
                    (item j [distance-from-other-turtles] of turtle k))
        ; is the alternate path shorter?
        if dummy < (item j [distance-from-other-turtles] of turtle i) [
          ask turtle i [
            set distance-from-other-turtles replace-item j distance-from-other-turtles dummy
          ]
        ]
        set j j + 1
      ]
      set i i + 1
    ]
    set k k + 1
  ]
end

;;;;;;;;;;;;;;;;;;;
;;Barabàsi-Albert;;
;;;;;;;;;;;;;;;;;;;
to setup-barabasi
  clear-all
  setup-turtles-barabasi
  set sorted-turtles sort turtles
  update-average-friends
  update-average-friends-of-friends
  reset-ticks
end

to setup-turtles-barabasi
  set-default-shape turtles "circle"
  make-node nobody
  make-node turtle 0
end

to go-barabasi
  if count turtles = num-nodes [stop]
  make-node find-partner
  layout
  update-average-friends
  update-average-friends-of-friends
  tick
end

to make-node [old-node]
  create-turtles 1 [
    if old-node != nobody [
      create-link-with old-node
      move-to old-node
      fd 8
    ]
    ;;set a popularity weight instead of checking if the turtle is popular
    set popularity-weight 0.0
    set popular? false
    if random-float 1.0 < prob-being-popular [ set popularity-weight random-float 0.5
    set popular? true]
    set label who
  ]
end

;;if the popularity is used the choice is weighted based on popularity, else it is chosen at random
to-report find-partner
  ifelse use-popularity-barabasi?[
    report [ rnd:weighted-one-of both-ends [popularity-weight]] of one-of links
  ][
    report [one-of both-ends] of one-of links
  ]
end

to layout
  repeat 3 [
    let factor sqrt count turtles
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display
  ]
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end


;;;;;;;;;;;;;;;;;;;;;
;;General-functions;;
;;;;;;;;;;;;;;;;;;;;;


;;create and initialize the agents
to setup-turtles
  set-default-shape turtles "circle"
  create-turtles num-nodes
  layout-circle turtles (max-pxcor - 1)
  ask turtles [
    set popular? false
    set popularity-weight random-float 0.5
    if random-float 1.0 < prob-being-popular [ set popular? true ]
    set label who
    ifelse popular? ;;set the friendliness for the game-theory model
    [ set friendliness (random-float 1.0 + popularity-weight) ]
    [ set friendliness random-float 1.0 ]
  ]
end

;;Update and calculate the average friends of a turtle
to update-average-friends
  ask turtles [
    set num-friends count link-neighbors
    set num-friends-squared (num-friends ^ 2)
    set average-friends ( num-friends / (count turtles) )
  ]
end

;;Update and calculate the average friends of friends of each turtle, by getting the sum of the number of friends squared for each of the linked turtles
to update-average-friends-of-friends
  ask turtles [
    let a 0 ;;temp variable for the sum of friends of friends squared
    ask in-link-neighbors
    [
      let b num-friends-squared
      set a a + b
    ]
    set sum-friends-of-friends-squared a
    ifelse num-friends != 0 [
      set average-friends-of-friends ( sum-friends-of-friends-squared / num-friends )
    ]
    [ set average-friends-of-friends 0 ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
1386
13
2536
1164
-1
-1
34.61
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
0
358
228
392
setup-Erdos
setup-Erdos
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
0
485
228
518
go-Erdos
go-Erdos
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
0
121
172
154
num-nodes
num-nodes
10
100
10.0
1
1
NIL
HORIZONTAL

PLOT
0
562
550
1181
Average friends
turtles
avg-friends
0.0
10.0
0.0
1.0
true
false
"set-plot-x-range 0 (num-nodes)" ""
PENS
"average friends" 1.0 1 -5298144 true "" "plot-pen-reset\nforeach sort turtles [ [t] -> ask t [ plot average-friends ] ]"

PLOT
550
561
1389
1182
Average friends of friends
turtles
avg-friends-of-friends
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 (num-nodes)\nset-plot-y-range 0 (num-nodes)" ""
PENS
"average-friends-of-friends" 1.0 1 -14070903 true "" "plot-pen-reset\nforeach sort turtles [ [t] -> ask t [ plot average-friends-of-friends ] ]"

BUTTON
228
358
438
392
NIL
setup-Watts
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
228
485
438
518
go-Wattz
go-Watts
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
438
358
637
392
setup-barabasi
setup-barabasi
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
438
485
637
518
go-barabasi
go-barabasi
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
0
206
166
239
use-popularity-barabasi?
use-popularity-barabasi?
0
1
-1000

BUTTON
637
485
835
518
NIL
go-game
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
209
121
381
154
prob-making-friends
prob-making-friends
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
208
208
380
241
prob-remove-friends
prob-remove-friends
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
403
170
575
203
prob-being-popular
prob-being-popular
0
1
0.5
0.05
1
NIL
HORIZONTAL

TEXTBOX
8
41
310
69
1. Set Model Parameters
23
55.0
1

TEXTBOX
25
103
175
121
Number of individuals
11
0.0
1

TEXTBOX
237
89
387
117
Probability an individual will make a new friend
11
0.0
1

TEXTBOX
426
140
576
168
probability an individual will be popular
11
0.0
1

TEXTBOX
5
177
155
205
Use Popularity in Barabasi model\n
11
0.0
1

TEXTBOX
217
176
367
204
Probability a friendship will be lost\n
11
0.0
1

TEXTBOX
0
278
741
310
2. Select the initial configuration based on the model
23
66.0
1

TEXTBOX
50
341
200
359
Use Erdos-Renyi model
11
0.0
1

TEXTBOX
276
343
426
361
Use Watts-Strogatz model
11
0.0
1

TEXTBOX
488
343
638
361
Use Barabasi model
11
0.0
1

TEXTBOX
0
404
602
427
3. Select which model to use to run the simulation
23
66.0
1

TEXTBOX
67
469
217
487
Run Erdos-Renyi model\n
11
0.0
1

TEXTBOX
281
469
431
487
Run Watts-Strogatz model
11
0.0
1

TEXTBOX
497
469
647
487
Run Barabasi model
11
0.0
1

TEXTBOX
677
454
827
482
Run Game Theory model(only with Erdos and Watts setup)
11
0.0
1

TEXTBOX
0
526
554
558
4. Observe the results
23
66.0
1

PLOT
969
269
1386
561
popularity
turtles
popular?
0.0
10.0
0.0
10.0
false
true
"set-plot-x-range 0 (num-nodes)\nset-plot-y-range 0 1" ""
PENS
"popularity" 1.0 1 -16777216 true "" "plot-pen-reset\nforeach sort turtles [ [t] -> ask t [ ifelse popular? [plot 1] [plot 0.5] ]]"

TEXTBOX
977
245
1352
263
Keeps track on which turtles are popular, 0.5 not popular, 1 popular\n
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve
3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve-a
-3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
