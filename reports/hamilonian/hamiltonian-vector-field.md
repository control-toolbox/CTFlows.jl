@vector_field.jl#L1-217 Nous avons ici un VectorField. J'aimerais ajouter un HamiltonianVectorField.

Soit Hv, un HamiltonianVectorField. Alors, on a la signature : 

```
dx, dp = Hv([t ,] x, p[, v])
```

À partir d'un HamiltonianVectorField, on pourra créer un System :

@abstract_system.jl#L1-239 
@building.jl#L1-38 
@vector_field_system.jl#L1-126 

Il faudra sûrement créer un HamiltonianVectorFieldSystem.

A partir d'un HamiltonianVectorFieldSystem, il faudra pouvoir créer un flot hamiltonien, qui en principe existe déjà : 

@abstract_flow.jl#L1-247
 @flow.jl#L131-134 à comparer avec @flow.jl#L101-104. 

Il faudra aussi pouvoir construire un flot, directement depuis le HamiltonianVectorField, comme on fait de manière analogue @building.jl#L29-34 .

Bien entendu, à partir d'un flot, qu'il soit hamiltonien ou non, on pourra l'appeler : @calling.jl#L1-46. J'espère que c'est suffisamment générique, la fonction call que il n'y aura pas grand chose à changer.

Pour intégrer un flot, nous avons besoin d'un intégrateur : @abstract_integrator.jl#L1-149 @sciml.jl#L1-171. Un intégrateur est une Strategy et doit donc implémenter certaines méthodes en ce sens, ce qu'il fait déjà. Mais c'est donc aussi un intégrateur. Et cela doit être clair, je pense, qu'il y a des fonctions qui peuvent avoir plusieurs méthodes en fonction du fait d'avoir un système hamiltonien ou pas. Cela peut aussi passer par la config, car quand on a un système hamiltonien, on va utiliser une config hamiltonienne @configs.jl#L1-625 . @CTFlowsSciML.jl#L1-592 : je n'ai pas l'impression qu'il y ait de distinction à ce niveau là. @integration_result.jl#L1-93 non plus ici. Peut-être au niveau des solutions, car en effet, une fois intégré le flot, il faut retourner une solution. 

Il faudra gérer la sortie : 

@building.jl#L1-67 

En effet, si on a un flot hamiltonien f, on voudra faire soit

```
xf, pf = f(t0, x0, p0, tf)
```

soit 

```
flow_sol = f((t0, tf), x0, p0)
```

avec la variable si le flot est variable.

Remarque : on pourra se poser la question de la nécessité d'avoir dans @building.jl#L23-24 @building.jl#L44-45 @building.jl#L64-65 à la fois le système et la config, qui doivent être les deux cohérents, car si on a un système hamiltonien, il faudra une config hamiltonien. Il est à noter que plus tard, nous aurons des flots construits à partir d'un problème de contrôle optimal, le flot hamiltonien et on voudra faire xf, pf = f(t0, x0, p0, tf) mais dans la version f((t0, tf), x0, p0) la solution retournée aura un type particulier : CTModels.Solution. Ce sera en fait une solution d'un problème de contrôle optimal.

Remarque : pour être très cohérent, doit-on appeler les configs PointConfig et TrajectoryConfig : StatePointConfig et StateTrajectoryConfig ?

Pour créer une solution particulière, on aura besoin de créer l'analogue de @vector_field_solution.jl#L1-291 . De manière équivalent, il y aura à gérer l'affichage mais aussi @CTFlowsPlots.jl#L1-101 . On pourra simplement faire un layout (1, 2) pour l'état et le co-état.

