using CSV
using DataFrames
using Polyhedra
using Statistics

struct ConvexHull
    polytope
    vertices
end

function ConvexHull(x::Matrix{Float64})::ConvexHull
    p = polyhedron(vrep(x))
    v = vrep(p).V
    ConvexHull(p, [v[i, :] for i in axes(v, 1)])
end

ConvexHull(x::DataFrame)::ConvexHull = ConvexHull(Matrix{Float64}(x))

inside(h::ConvexHull, p::Vector{Float64})::Bool = p ∈ h.polytope

function parse_args(args)
    parsed = Dict{String,String}()
    i = 1
    while i <= length(args)
        key = args[i]
        if !startswith(key, "--")
            error("Unexpected argument: $key")
        end
        if i == length(args) || startswith(args[i + 1], "--")
            parsed[key] = "true"
            i += 1
        else
            parsed[key] = args[i + 1]
            i += 2
        end
    end
    parsed
end

function required_arg(args, key)
    haskey(args, key) || error("Missing required argument: $key")
    args[key]
end

function component_pairs(vars)
    pairs = Vector{Tuple{String,String}}()
    for from in vars
        for to in vars
            from == to && continue
            push!(pairs, (from, to))
        end
    end
    pairs
end

function shifted_mask(df, hull, vars, from, to, duration)
    if duration == 0
        return trues(nrow(df))
    end

    from_idx = findfirst(==(from), vars)
    to_idx = findfirst(==(to), vars)
    from_idx === nothing && error("Unknown from component: $from")
    to_idx === nothing && error("Unknown to component: $to")

    x = Matrix{Float64}(df[:, vars])
    mask = Vector{Bool}(undef, size(x, 1))
    for i in axes(x, 1)
        candidate = vec(x[i, :])
        candidate[from_idx] -= duration
        candidate[to_idx] += duration
        mask[i] = inside(hull, candidate)
    end
    mask
end

function clipped_duration(point, hull, from_idx, to_idx, duration; tolerance = 1e-6)
    duration == 0 && return 0.0

    candidate = copy(point)
    candidate[from_idx] -= duration
    candidate[to_idx] += duration
    inside(hull, candidate) && return Float64(duration)

    low = 0.0
    high = 1.0
    while abs(duration) * (high - low) > tolerance
        mid = (low + high) / 2
        candidate = copy(point)
        candidate[from_idx] -= mid * duration
        candidate[to_idx] += mid * duration
        if inside(hull, candidate)
            low = mid
        else
            high = mid
        end
    end

    low * duration
end

function applied_durations(df, hull, vars, from, to, duration)
    from_idx = findfirst(==(from), vars)
    to_idx = findfirst(==(to), vars)
    from_idx === nothing && error("Unknown from component: $from")
    to_idx === nothing && error("Unknown to component: $to")

    x = Matrix{Float64}(df[:, vars])
    [
        clipped_duration(vec(x[i, :]), hull, from_idx, to_idx, duration)
        for i in axes(x, 1)
    ]
end

function support_ratio(df, hull, vars, from, to, duration)
    mean(shifted_mask(df, hull, vars, from, to, duration))
end

function support_frontier(df, hull, vars, from, to, ratio_threshold, max_minutes)
    max_minutes <= 0 && return 0
    support_ratio(df, hull, vars, from, to, max_minutes) >= ratio_threshold && return max_minutes

    low = 0
    high = max_minutes
    while (high - low) > 1
        mid = fld(low + high, 2)
        if support_ratio(df, hull, vars, from, to, mid) >= ratio_threshold
            low = mid
        else
            high = mid
        end
    end
    low
end

function write_frontiers(df, hull, vars, path, ratio_threshold, max_minutes)
    rows = DataFrame(from = String[], to = String[], max_supported_minutes = Int[])
    for (from, to) in component_pairs(vars)
        push!(
            rows,
            (
                from = from,
                to = to,
                max_supported_minutes = support_frontier(
                    df,
                    hull,
                    vars,
                    from,
                    to,
                    ratio_threshold,
                    max_minutes,
                ),
            ),
        )
    end
    CSV.write(path, rows)
end

function write_masks(df, hull, vars, substitutions_path, masks_path)
    substitutions = CSV.read(substitutions_path, DataFrame)
    out = DataFrame(
        from = String[],
        to = String[],
        duration = Int[],
        row_id = Int[],
        PID = String[],
        substituted = Bool[],
        applied_duration = Float64[],
    )

    pid_values = string.(df.PID)
    row_ids = Int.(df.row_id)
    for row in eachrow(substitutions)
        from = String(row.from)
        to = String(row.to)
        duration = Int(row.duration)
        mask = shifted_mask(df, hull, vars, from, to, duration)
        realized = applied_durations(df, hull, vars, from, to, duration)
        append!(
            out,
            DataFrame(
                from = fill(from, nrow(df)),
                to = fill(to, nrow(df)),
                duration = fill(duration, nrow(df)),
                row_id = row_ids,
                PID = pid_values,
                substituted = mask,
                applied_duration = realized,
            ),
        )
    end
    CSV.write(masks_path, out)
end

function main()
    args = parse_args(ARGS)
    input_path = required_arg(args, "--input")
    vars = split(required_arg(args, "--vars"), ",")

    df = CSV.read(input_path, DataFrame)
    x = Matrix{Float64}(df[:, vars])
    hull = ConvexHull(x)

    if haskey(args, "--frontiers")
        ratio_threshold = parse(Float64, get(args, "--ratio-threshold", "0.75"))
        max_minutes = parse(Int, get(args, "--max-minutes", "60"))
        write_frontiers(df, hull, vars, args["--frontiers"], ratio_threshold, max_minutes)
    end

    if haskey(args, "--masks")
        substitutions_path = required_arg(args, "--substitutions")
        write_masks(df, hull, vars, substitutions_path, args["--masks"])
    end
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
