struct PointConfig{T0, X0, TF}
    t0::T0
    x0::X0
    tf::TF
end

struct TrajectoryConfig{TS, X0}
    tspan::TS
    x0::X0
end
