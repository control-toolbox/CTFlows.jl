const DIFFGEO_PREFIX = Ref{Symbol}(:CTFlows)
diffgeo_prefix()::Symbol = DIFFGEO_PREFIX[]
diffgeo_prefix!(p::Symbol) = (DIFFGEO_PREFIX[] = p; nothing)
