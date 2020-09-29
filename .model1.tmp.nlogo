breed [healthys healthy]
breed [sicks sick]
breed [houses house]

turtles-own [
  healthy?
  sick?
  sick-time
  immune?
  immune-time
  homebase
  severity    ;; where 0 = mild and 1 = severe symptoms
  lockdown?
  rangeClass age gender
  death-prob
  wear-mask?
  asymptomatic?
  occupation
]


globals [
  cycle-days
  day hour
  tick-day
  n-sicks
  n-healthys
  n-deaths
  n-leaks
  n-mask
  n-waves
  n-asymptomatic
  max-infecteds
]

to setup
  clear-all
  set n-leaks 0
  set n-deaths 0
  set tick-day 10
  set n-sicks 0
  set n-healthys 0
  set n-waves 1
  set max-infecteds 0
  setup-city
  setup-population
  setup-sectors
  ask n-of initial-infecteds healthys
  [ become-infected
    set max-infecteds (max-infecteds + 1) ]
  reset-ticks
end

to go
  adjust
  return-home
  if immunity-duration?
    [ immunity-control ]
  tick
end

to setup-city
   create-houses (population / 3) [
     setxy (random-xcor * 0.95) (random-ycor * (0.50))
     set color white set shape "house" set size 12
   ]

  ; sector: school
  let school-area patches with [pxcor > 50 and pycor > 90]
  ask school-area [ set pcolor sky + 2 ]

  ; sector: industry
  let industry-area patches with [pxcor > -58 and pxcor < 58 and pycor < -90]
  ask industry-area [ set pcolor violet + 2 ]

  ; sector: commerce
  let commerce-area patches with [pxcor < -60  and pycor < -90]
  ask commerce-area [ set pcolor green + 2]

  ; sector: servicesf
  let service-area patches with [pxcor > 60  and pycor < -90]
  ask service-area [ set pcolor brown + 2]

  ; sector: construction
  let construction-area patches with [pxcor < -10 and pycor > 90]
  ask construction-area [ set pcolor orange + 2 ]
end

to setup-sectors
  let aux count healthys with[rangeClass = "elderly"]

  ; sector: retired
  ask n-of ((aux * %-retired) / 100) healthys with[rangeClass = "elderly"]
  [ set occupation "retired" ]

  set aux count healthys with[occupation = "student" or occupation = "retired"]
  let totalPop (population - aux)
  let totalPercentage 0

  ; sector: services
  ask n-of ((totalPop * %-services) / 100) healthys with[occupation = "none"]
  [ set occupation "services"
    set totalPercentage %-services  ]

  ; sector: commerce
  if totalPercentage != 100
  [
    ifelse (totalPercentage + %-commerce) <= 100
    [ ask n-of ((totalPop * %-commerce) / 100) healthys with[occupation = "none"]
      [ set occupation "commerce"
        set totalPercentage (%-services + %-commerce) ]
    ]
    [
      set aux count healthys with[occupation = "none"]
      ask n-of aux healthys with[occupation = "none"]
      [ set occupation "commerce"
        set totalPercentage 100 ]
    ]
  ]

  ; sector: industry
  if totalPercentage != 100
  [
    ifelse totalPercentage + %-industry <= 100
    [ ask n-of ((totalPop * %-industry) / 100) healthys with[occupation = "none"]
      [ set occupation "industry"
        set totalPercentage (%-services + %-commerce + %-industry) ]
    ]
    [
      set aux count healthys with[occupation = "none"]
      ask n-of aux healthys with[occupation = "none"]
      [ set occupation "industry"
        set totalPercentage 100 ]
    ]
  ]

  ; sector: construction
  if totalPercentage != 100
  [
    ifelse totalPercentage + %-construction <= 100
    [ ask n-of ((totalPop * %-construction) / 100) healthys with[occupation = "none"]
      [ set occupation "construction"
        set totalPercentage (%-services + %-commerce + %-industry + %-construction) ]
    ]
    [
      set aux count healthys with[occupation = "none"]
      ask n-of aux healthys with[occupation = "none"]
      [ set occupation "construction"
        set totalPercentage 100 ]
    ]
  ]

  set aux count healthys with[occupation = "none"]
  ask n-of aux healthys with[occupation = "none"]
  [ if occupation = "none"
    [ set occupation "services" ]
  ]
end

to setup-population
  set-default-shape turtles "person"
  create-turtles population
  [
    set color green
    set size 7
    set breed healthys
    set occupation "none"
    set sick? false
    set sick-time 0
    set immune? false
    set immune-time 0
    set healthy? true
    set lockdown? true
    set severity 0
    set rangeClass "none"
    set gender "none"
    set wear-mask? false
    set asymptomatic? false
    set homebase one-of houses
    move-to homebase
  ]
  setup-range-age
  setup-death-rate
  setup-gender
  setup-asymptomatics
  setup-mask-adhrents
  setup-population-leak
  setup-students
  ask n-of (population / 20) healthys with[not asymptomatic?]
  [ set severity 1 ]
end

to setup-range-age
  ask n-of ((population * 13.82) / 100) healthys
  [
    set rangeClass "elderly"
    set age (random (100 - 60 + 1) + 60)
  ]
  ask n-of ((population * 56.65) / 100) healthys with[rangeClass = "none"]
  [
    set rangeClass "adult"
    set age (random (59 - 20 + 1) + 20)
  ]
  ask n-of ((population * 23.32) / 100) healthys with[rangeClass = "none"]
  [
    set rangeClass "youth"
    set age (random (19 - 5 + 1) + 19)
  ]
end

to setup-asymptomatics
  let asymptomatics ((population * %-asymptomatics) / 100)
  ask n-of asymptomatics healthys with[rangeClass = "adult" or rangeClass = "youth"]
  [ set asymptomatic? true
    set n-asymptomatic (n-asymptomatic + 1) ]
end

to setup-death-rate
  ask n-of population healthys
  [
    if age >= 5 and age <= 9 [ set death-prob 0.1 ]
    if age >= 10 and age <= 39 [ set death-prob 0.2 ]
    if age >= 40 and age <= 49 [ set death-prob 0.4 ]
    if age >= 50 and age <= 59 [ set death-prob 1.3 ]
    if age >= 60 and age <= 69 [ set death-prob 3.6 ]
    if age >= 70 and age <= 79 [ set death-prob 8 ]
    if age >= 80 [ set death-prob 14.8 ]
  ]
end

to setup-mask-adhrents
  ifelse %-mask-adhrents != 100
  [
    let adhrents ((population * %-mask-adhrents) / 100)
    ask n-of ((adhrents * 50) / 100) healthys with[gender = "woman"]
    [ set wear-mask? true
      set n-mask (n-mask + 1) ]
    ask n-of ((adhrents * 50) / 100) healthys with[not wear-mask?]
    [ set wear-mask? true
      set n-mask (n-mask + 1) ]
  ]
  [
    ask n-of population healthys
    [ set wear-mask? true
      set n-mask population ]
  ]
end

to setup-gender
  let qtd-elderly ((population * 13.82) / 100)
  let qtd-adult ((population * 56.65) / 100)
  let qtd-youth ((population * 23.32) / 100)

  ; elderly gender
  ask n-of ((qtd-elderly * 58.3) / 100) healthys with[rangeClass = "elderly" and gender = "none"]
  [ set gender "woman" ]
  ask n-of ((qtd-elderly * 41.7) / 100) healthys with[rangeClass = "elderly" and gender = "none"]
  [ set gender "man" ]

  ; adult gender
  ask n-of ((qtd-adult * 51.52) / 100) healthys with[rangeClass = "adult" and gender = "none"]
  [ set gender "woman" ]
  ask n-of ((qtd-adult * 48.48) / 100) healthys with[rangeClass = "adult" and gender = "none"]
  [ set gender "man" ]

  ; youth gender
  ask n-of ((qtd-youth * 49.45) / 100) healthys with[rangeClass = "youth" and gender = "none"]
  [ set gender "woman" ]
  ask n-of ((qtd-youth * 50.55) / 100) healthys with[rangeClass = "youth" and gender = "none"]
  [ set gender "man" ]
end

to setup-population-leak
  ask n-of ((population * %-population-leak) / 100) healthys with[occupation != "student"]
  [
    set lockdown? false
    set n-leaks n-leaks + 1
  ]
end

to setup-students
  ask n-of population healthys
    [ if rangeClass = "youth"
      [ set occupation "student" ]
    ]
end

to clock
  set day int (ticks / tick-day)
  set hour int ((ticks / tick-day) * 24)
end

to adjust
  set cycle-days 0
  let lockdown-counter (tick-day * lockdown-duration)
  let workday-counter (tick-day * workday-duration)
  while [ cycle-days < (lockdown-counter + workday-counter) + 1 ]
  [
    ifelse cycle-days < workday-counter + 1
    [ open-sectors
      epidemic ]
    [ ad-lockdown ]
    if ticks mod tick-day = 0
    [ set cycle-days (cycle-days + tick-day) ]
    tick
    clock
  ]
end

to ad-lockdown
  let people (turtle-set healthys sicks)
  ask people
  [
    ifelse not lockdown?
    [ move-turtles ]
    [ move-to homebase
      forward 0
      set lockdown? true ]
  ]
  ask houses [
    set color ifelse-value any? sicks-here with [ sick? ][ red ][ white ]
  ]
  epidemic
  recover-or-die
end

to move-turtles
  ask turtles with [shape = "person" and not lockdown?][
    let current-turtle self
    if occupation != "student" [
      if [pcolor] of patch-ahead 1 != sky + 2 [
        set heading heading + (random-float 3 - random-float 3)
        forward 1]
      if [pcolor] of patch-ahead 3 = sky + 2 [
        set heading heading - 100
        forward 1
      ]
    ]

    if occupation != "industry" [
      if [pcolor] of patch-ahead 1 != violet + 2 [
        set heading heading + (random-float 3 - random-float 3)
        forward 1]
      if [pcolor] of patch-ahead 3 = violet + 2 [
        set heading heading - 100
        forward 1
      ]
    ]

    if distance current-turtle < 1 + (count sicks) [
        set heading heading + (random-float 5 - random-float 5)]
  ]
  epidemic
end

to open-sectors
  if open-school?
  [ ask turtles with[shape = "person"]
    [ if occupation = "student"
      [
        ifelse sick? and not asymptomatic?
        [ move-to homebase
          forward 0 ]
        [ move-to one-of patches with [pcolor = sky + 2] ]
      ]
      if not lockdown?
      [ move-turtles ]
    ]
  ]

   if open-services?
  [ ask turtles with[shape = "person"]
    [ if occupation = "services"
      [
        ifelse sick? and not asymptomatic?
        [ move-to homebase
          forward 0 ]
        [ move-to one-of patches with [pcolor = brown + 2] ]
      ]
      if not lockdown?
      [ move-turtles ]
    ]
  ]

   if open-commerce?
  [ ask turtles with[shape = "person"]
    [ if occupation = "commerce"
      [
        ifelse sick? and not asymptomatic?
        [ move-to homebase
          forward 0 ]
        [ move-to one-of patches with [pcolor = green + 2] ]
      ]
      if not lockdown?
      [ move-turtles ]
    ]
  ]

  if open-industry?
  [ ask turtles with[shape = "person"]
    [ if occupation = "industry"
      [
        ifelse sick? and not asymptomatic?
        [ move-to homebase
          forward 0 ]
        [ move-to one-of patches with [pcolor = violet + 2] ]
      ]
      if not lockdown?
      [ move-turtles ]
    ]
  ]

  if open-construction?
  [ ask turtles with[shape = "person"]
    [ if occupation = "construction"
      [
        ifelse sick? and not asymptomatic?
        [ move-to homebase
          forward 0 ]
        [ move-to one-of patches with[pcolor = orange + 2 ] ]
      ]
      if not lockdown?
      [ move-turtles ]
    ]
  ]
  epidemic
  return-home
end

to move-to-school
  if open-school?
  [
    ask turtles with[shape = "person"][
      if occupation = "student"
      [
        ifelse sick? and severity = 1
        [ move-to homebase
          forward 0 ]
        [ move-to one-of patches with [pcolor = yellow] ]
      ]
      if not lockdown?
      [ move-turtles ]
    ]
    epidemic
    return-home
  ]
end

to return-home
  ask turtles with[shape = "person"]
  [
    if ticks mod tick-day = 4
      [ move-to homebase]
  ]
end

to epidemic
  ask sicks [
    let current-sick self
    let current-sick-home 0
    let current-sick-mask? false
    ask current-sick
    [ set current-sick-home homebase
      set current-sick-mask? wear-mask?]
    ifelse not lockdown?
    [
      ask healthys with[distance current-sick < 2 and not immune?]
      [
        ifelse current-sick-mask? [
          if random 100 < mask-effectivity
          [ if random-float 100 < 2.4
            [ become-infected
              set max-infecteds (max-infecteds + 1)]
          ]
        ]
        [ if random-float 100 < 2.4
          [ become-infected
            set max-infecteds (max-infecteds + 1)]
        ]
      ]
    ]
    [
      ask healthys with[lockdown? and not immune? and current-sick-home = homebase]
      [ if rangeClass = "youth"
        [ if random-float 100 < 6.4
          [ become-infected
            set max-infecteds (max-infecteds + 1)]
        ]
        if rangeClass = "adult"
        [ if random-float 100 < 17.1
          [ become-infected
            set max-infecteds (max-infecteds + 1)]
        ]
        if rangeClass = "elderly"
        [ if random-float 100 < 28
          [ become-infected
            set max-infecteds (max-infecteds + 1)]
        ]
      ]
    ]
  ]
end

to set-infected
  ask one-of healthys
    [ become-infected ]
end

to new-wave
  let aux (count healthys with[not immune?])
  if aux >= initial-infecteds
  [
    set n-waves (n-waves + 1)
    ask n-of initial-infecteds healthys with[not immune?]
    [ become-infected ]
  ]
end

to become-infected
  set breed sicks
  set sick-time day
  set color red
  set sick? true
  set immune? false
  set healthy? false
end

to become-well
  set color gray
  set immune? true
  set immune-time day
  set sick? false
  set breed healthys
end

to recover-or-die
   ask sicks with[not asymptomatic? and sick-time <= (day - 3)]
   [ move-to homebase
     forward 0
     set lockdown? true ]
   ask sicks with[severity = 0 and sick-time <= day - (random(14 - 7 + 1) + 7)]
   [
     ifelse random-float 100.0 < death-prob
     [ set n-deaths n-deaths + 1
       die ]
     [ become-well ]
   ]
   ask sicks with[severity = 1 and sick-time <= day - (random(56 - 14 + 1) + 14)]
   [
     ifelse random-float 100.0 <= death-prob
     [ set n-deaths n-deaths + 1
       die ]
     [ become-well ]
   ]
end

to immunity-control
  ask healthys with[immune? and immune-time <= day - 92]
    [ set immune? false
      set color green
      set immune-time 0 ]
end

; Report data of simulation
to-report total-infected
  report count sicks
end

to-report max-sicks
  let aux count sicks
  report max-infecteds
end

to-report total-deaths
  report n-deaths
end

to-report num-of-waves
  report n-waves
end

to-report n-mask-adhrents
  report n-mask
end

to-report n-population-leak
  report n-leaks
end

to-report n-of-asymptomatics
  report n-asymptomatic
end
@#$#@#$#@
GRAPHICS-WINDOW
389
16
851
479
-1
-1
1.51
1
10
1
1
1
0
1
1
1
-150
150
-150
150
0
0
1
ticks
30.0

SLIDER
22
95
194
128
population
population
12
999
51.0
3
1
NIL
HORIZONTAL

BUTTON
21
19
84
52
NIL
setup
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
93
19
156
52
NIL
go
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
863
39
994
72
lockdown-duration
lockdown-duration
0
31
10.0
1
1
NIL
HORIZONTAL

TEXTBOX
864
10
1049
32
Cyclic strategy
16
93.0
1

SLIDER
999
39
1143
72
workday-duration
workday-duration
0
31
5.0
1
1
NIL
HORIZONTAL

TEXTBOX
24
70
220
88
Population characteristics\n\n
16
93.0
1

PLOT
865
163
1234
376
Populations
days
people
0.0
92.0
0.0
300.0
true
true
"" ""
PENS
"total" 1.0 0 -13345367 true "" "let people (turtle-set healthys sicks)\nplot count people"
"never-infected" 1.0 0 -14439633 true "" "plot count healthys with [ not immune? ]"
"sick" 1.0 0 -2674135 true "" "plot count sicks with [ sick? ]"
"immunes" 1.0 0 -7500403 true "" "plot count healthys with [ immune? ]"

MONITOR
866
382
938
427
N. infecteds
total-infected
0
1
11

MONITOR
390
16
457
61
Clock:
(word day \"d, \" (hour mod 24) \"h\")
17
1
11

SLIDER
202
95
374
128
initial-infecteds
initial-infecteds
0
100
51.0
1
1
NIL
HORIZONTAL

BUTTON
202
19
279
52
NIL
set-infected
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1064
382
1127
427
N. deaths
total-deaths
17
1
11

SLIDER
21
140
193
173
%-population-leak
%-population-leak
0
100
0.0
1
1
%
HORIZONTAL

SWITCH
21
244
193
277
immunity-duration?
immunity-duration?
1
1
-1000

TEXTBOX
22
226
209
254
(if on, immunity duration = 92 days)
11
0.0
1

SLIDER
203
185
375
218
mask-effectivity
mask-effectivity
0
100
100.0
1
1
%
HORIZONTAL

SLIDER
22
184
194
217
%-mask-adhrents
%-mask-adhrents
0
100
100.0
1
1
%
HORIZONTAL

SLIDER
202
140
374
173
%-asymptomatics
%-asymptomatics
0
50
50.0
1
1
%
HORIZONTAL

BUTTON
289
19
378
52
NIL
new-wave
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1172
315
1222
360
Wave
num-of-waves
17
1
11

SLIDER
242
322
346
355
%-industry
%-industry
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
131
323
236
356
%-commerce
%-commerce
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
20
322
124
355
%-services
%-services
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
20
424
125
457
%-retired
%-retired
0
100
0.0
1
1
NIL
HORIZONTAL

SWITCH
864
116
994
149
open-school?
open-school?
0
1
-1000

TEXTBOX
22
293
172
313
Sectors
16
93.0
1

TEXTBOX
79
297
365
325
(% of the adult and elderly population in a given sector)
11
0.0
1

TEXTBOX
22
407
149
435
% of retired elderly
11
0.0
1

SWITCH
864
78
994
111
open-services?
open-services?
0
1
-1000

SWITCH
1000
77
1144
110
open-commerce?
open-commerce?
0
1
-1000

SWITCH
1150
78
1280
111
open-industry?
open-industry?
0
1
-1000

SLIDER
19
361
126
394
%-construction
%-construction
0
100
20.0
1
1
NIL
HORIZONTAL

SWITCH
1001
115
1144
148
open-construction?
open-construction?
0
1
-1000

PLOT
1248
165
1532
479
Sector population
NIL
NIL
0.0
10.0
10.0
10.0
true
true
"" ""
PENS
"industry" 1.0 0 -5204280 true "" "plot count turtles with[occupation = \"industry\"]"
"commerce" 1.0 0 -6565750 true "" "plot count turtles with[occupation = \"commerce\"]"
"services" 1.0 0 -3889007 true "" "plot count turtles with[occupation = \"services\"]"
"school" 1.0 0 -8275240 true "" "plot count turtles with[occupation = \"student\"]"
"construction" 1.0 0 -612749 true "" "plot count turtles with[occupation = \"construction\"]"
"retired" 1.0 0 -16448764 true "" "plot count turtles with[occupation = \"retired\"]"

MONITOR
946
482
1048
527
N. mask adhrents
n-mask-adhrents
17
1
11

MONITOR
945
434
1097
479
N. people breaking lockdown
n-population-leak
17
1
11

MONITOR
1135
382
1235
427
N. asymptomatics
n-of-asymptomatics
17
1
11

MONITOR
941
382
1061
427
Max n. of infecteds
max-sicks
17
1
11

@#$#@#$#@
## WHAT IS IT?

O modelo desenvolvido busca lidar com a problemática levantada no estudo de Karin et al. [1]  referente aos países que aderem ao lockdown. Uma estratégia comum dessas regiões que é colocada em questão é a de que o bloqueio da movimentação e atividades econômicas ocorre quando um número limite de casos é excedido e o desbloqueio, quando os casos diminuem. Porém, apesar dessa estratégia contribuir para impedir o sobrecarregamento dos serviços de saúde, ao mesmo tempo continua a acumular casos com cada nova onda, além de levar à incerteza econômica. 

Logo, é proposta uma estratégia cíclica adaptativa para o lockdown através de um modelo matemático, onde em suas variáveis de adaptação são levados em consideração x dias, onde a população realiza suas atividades no meio social, e y dias, onde a população mantém-se em lockdown. No presente modelo, buscou-se adaptar essa estratégia e levar alguns fatores levantados no estudo para uma realizar uma simulação do retorno das aulas presenciais.

## HOW IT WORKS

O  foco  da simulação é analisar  como  a  onda  de  novos  casos  de  Covid-19  comporta-se através da estratégia cíclica adaptativa de lockdown em uma situação de retorno das aulas presenciais, podendo compara-la com a estratégia padrão de lockdown ou sem nenhuma restrição de movimentação. Assim, podemos observar como essas diferentes estratégias afetam o número de infectados e mortos ao longo do tempo por essa doença.

Logo, foram definidas três tipos de estratégias: 

- **"Cyclic"**: onde durante uma quantidade _x_ de dias a população estudantil poderá ir para a escola e durante uma quantidade _y_, ficará em lockdown em sua casa juntamente com sua família.

- **"Lockdown"**: onde toda a população ficará durante tempo indeterminado em isolamento em cada casa.

- **"None"**: onde nenhuma medida de isolamento é tomada, ou seja, a população movimenta-se livremente pelo ambiente.

## HOW TO USE IT

Para rodar a simulação, aperte SETUP e depois GO. Visto que a simulação busca analisar a estratégia escolhida ao longo do tempo, para finalizá-la é necessário apertar novamente o botão GO para o deselecionar. 


O slider POPULATION controla quantas pessoas são levadas em consideração na simulação. A quantidade selecionada é um múltiplo de 3, visto que essa população será dividida em HOMEBASES (famílias) e a média de pessoas por família no Brasil é igual a 3, de acordo com o IBGE [2].

Para determinar a quantidade de infectados iniciais de uma população, utilize o slider INITIAL-INFECTEDS. O botão SET-INFECTED seleciona um pessoa aleatória da população e a torna infetada.

A variável RECOVERY-PROBABILITY determina a probabilidade máxima de uma pessoa da população, após a contaminação, recuperar-se e tornar-se imune a doença. Enquanto que a variável INFECTIOUNESS-PROBABILITY determina a probabilidade máxima de uma pessoa infectada da população contaminar outra pessoa próxima.

O slider %-POPULATION-LEAK determina a porcentagem da população que não adere ao lockdown, movimentando-se pelo ambiente.

O seletor STRATEGY-TYPE determina a estratégia que será utilizada na simulação, podendo variar entre uma estratégia cíclica, lockdown ou none (nenhuma medida de isolamento é tomada). Visto que essa simulação busca analisar principalmente a estratégia cíclica, ela é tida como valor inicial desse seletor.

Se a variável PREVENTION-CARE? está em "On", a probabilidade de infectar outra pessoa (INFECTIOUNESS-PROBABILITY) é diminuída em até 60%, porcentagem estimada através de estudos [3, 4] que levam em consideração a utilização de máscaras e cuidados de higiene. 

Os sliders LOCKDOWN-DURATION e SCHOOLDAY-DURATION determinam a quantidade de dias do cronograma da estratégia cíclica, onde LOCKDOWN-DURATION determina quantos dias a população ficará isolada em casa, enquanto SCHOOLDAY-DURATION determina quantos dias a população estudantil irá mover-se de casa para a escola.

## THINGS TO TRY

Lembre-se de testar com PREVENTION-CARE? ligado e desligado. Além disso, teste com mais dias de escola e menos dias de lockdown para verificar o comportamento. Verifique os resultados obtidos a partir de diferentes taxas de aderência ao isolamento (%-POPULATION-LEAK).

## EXTENDING THE MODEL

Sugere-se aumentar o modelo e simulá-lo com um número maior de escolas, levando em consideração o transporte dos estudantes até elas (podendo ser infectado nesse caminho, caso utilize transportes públicos). Além disso, recomenda-se adicionar o fator de idade que afeta a probabilidade de recuperação, levando em conta a severidade dos sintomas. Por fim, é interessante simular a "quebra" do lockdown não apenas para aqueles que circulam pelo ambiente, mas também para os que visitam outras casas.  

## RELATED MODELS

Alvarez, L. and Rojas-Galeano, S. “Simulation of Non-Pharmaceutical Interventions on COVID-19 with an Agent-based Model of Zonal Restraint”. medRxiv pre-print 2020/06/13; https://www.medrxiv.org/content/10.1101/2020.06.13.20130542v1 DOI: 10.1101/2020.06.13.20130542

## CREDITS AND REFERENCES

[1] Karin, Omer & Bar-On, Yinon & Milo, Tomer & Katzir, Itay & Mayo, Avi & Korem, Yael & Dudovich, Boaz & Zehavi, Amos & Davidovich, Nadav & Milo, Ron & Alon, Uri. (2020). Adaptive cyclic exit strategies from lockdown to suppress COVID-19 and allow economic activity. DOI: 10.1101/2020.04.04.20053579. 

[2] Ohana, Victor. (2019). IBGE: 2,7% das famílias ganham um quinto de toda a renda no Brasil. Acesso em: 22/06/2020, https://www.cartacapital.com.br/sociedade/ibge-27-das-familias-ganham-um-quinto-de-toda-a-renda-no-brasil/amp/

[3] Holanda, Debora. (2020). Simulador para estudo de comportamento do COVID-19 na população brasileira. Acesso em: 22/06/2020, https://medium.com/@holanda.debora/simulador-para-estudo-de-comportamento-do-covid-19-na-população-brasileira-c809ea8586c9.

[4] Macintyre, Chandini & Chughtai, Abrar. (2015). Facemasks for the prevention of infection in healthcare and community settings. DOI: 10.1136/bmj.h69
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
NetLogo 6.1.1
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
@#$#@#$#@
0
@#$#@#$#@
