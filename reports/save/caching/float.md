Au lieu de faire un cache lazy, on pourrait convertir dans les configs, tous les int en float, en respectant le type de l'état. `float(x)` fonctionne sur les scalaires et les vecteurs, réels et complexes.

Ainsi, on peut faire un cache et ne pas avoir une struct mutable.

Pour la géo, diff, c'est plus dur.