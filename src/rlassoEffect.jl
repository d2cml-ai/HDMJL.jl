
function rlassoEffect(
        x, 
        y, 
        d;
        method = "double selection",
        I3 = nothing,
        post = true
    )

    #= x = Matrix(x)
    y = Matrix(y[:, :])
    d = Matrix(d[:, :]) =#

    n, p = size(x)

    # i3 = Set(I3)

    if method == "double selection"
        I1 = rlasso(x, d, post = post)["index"]
        I2 = rlasso(x, y, post = post)["index"]

        if !isnothing(I3)
            I = I1 + I2 + I3
        else
            I =  I1 + I2
        end

        if sum(I) == 0
            I = nothing
        end
    
        I[I .> 0] .= 1
        I = BitVector(I)
       
        x = hcat(ones(n), d, x[:, I])
        reg1 = GLM.lm(x, y)
        alpha = GLM.coef(reg1)[2]
    
        xi = GLM.residuals(reg1) .* sqrt(n / (n - sum(I) - 1))
    
        if isnothing(I)
            reg2 = GLM.lm(ones(n, 1), d)
        else
            reg2 = GLM.lm(x[:, Not(2)], d)
        end
    
        v = GLM.residuals(reg2)
    
        var_r = 1 / n * 1 /mean(v.^2) * mean(v.^2 .* xi.^2) * 1 / mean(v.^2)
    
        se = sqrt(var_r)
    
        tval = alpha / se
    
        # pval = 2 ##3 searching function (`pnorm`)
    
       if isnothing(I)
            no_select = 1
        else
            no_select = 0
        end
    
        res = Dict(
            "epsilon" => xi, "v" => v
        )

        results = Dict(
            "alpha" => alpha, "se" => se, "t" => tval,
            "no_select" => no_select, "coefficients" => alpha, "coefficient" => alpha,
            "coefficients_reg" => GLM.coef(reg1), "selection_index" => I, "residuals" => res,
            "sample_size" => n
        )
    elseif method == "partialling out"
        reg1 = rlasso(x, y, post = post)
        yr = reg1["residuals"]
        reg2 = rlasso(x, d, post = post)
        dr = reg2["residuals"]

        data0 = hcat(yr, ones(n), dr)
        reg3 = GLM.lm(data0[:, Not(1)], data0[:, 1])
        alpha = GLM.coef(reg3)[2]

        var = vcov(reg3)[2, 2]
        se = sqrt.(var)
        tval = alpha ./ sqrt(var)
        # pval = 
        res = Dict("epsilon" => GLM.residuals(reg3), "v" => dr)

        I1 = reg1["index"]
        I2 = reg2["index"]
        I = as_logical(I1 + I2)
        results = Dict(
            "alpha" => alpha, "se" => se, "t" => tval, "coefficients" => alpha,
            "coefficient" => alpha, "coefficients_reg" => reg1["coefficients"], "selection_index" => I,
            "residuals" => res, "sample_size" => n
        )

    end

    return results

end



function rlassoEffects(x, y; index = 1:size(x, 2), I3 = nothing, method = "partialling out", post = true)

    # if method ∉ ["partialling out", "double selection"]
        # print("Method not found, select from [partialling out, double selection")
    # end

    if length(Set(index)) == 2
        k = p1 = sum(index)
    else
        k = p1 = length(index)
    end

    n, p = size(x)

    names_x = try names(x)
        catch
            nothing
        end
    x0 = Matrix(x[:, :])
    # y0 = Matrix(y[:, 1])

    if isnothing(names_x)
        names_x = []
        for i in 1:p
            push!(names_x, "V $i")
        end
    end

    coefficients = zeros(k)
    se = zeros(k)
    t = zeros(k)
    pval = zeros(k)

    lasso_reg = Dict()
    reside = zeros(n, p1)
    residv = zeros(n, p1)
    coef_mat = Dict()
    selection_matrix = zeros(n, k)

#   names(coefficients) <- names(se) <- names(t) <- names(pval) <- names(lasso.regs) <- colnames(reside) <- colnames(residv) <- colnames(selection.matrix) <- colnames(x)[index]
    for i in 1:k
        d = x0[:, i]
        xt = x0[:, Not(i)]
        # Variables de control
        if isnothing(I3)
            I3m = I3
        else
            I3m = I3[Not(index[i])]
        end
        lasso_reg[i] = try
            rlassoEffect(xt, y, d, method = method, I3 = I3m, post = post)
        catch
            "try-error"
        end

        if lasso_reg[i] == "try-error"
            continue
        else
            coefficients[i] = lasso_reg[i]["alpha"]
            se[i] = lasso_reg[i]["se"]
            t[i] = lasso_reg[i]["t"]
            # pval[i] = lasso_reg[i]["p_value"]
            reside[:, i] = lasso_reg[i]["residuals"]["epsilon"]
            residv[:, i] = lasso_reg[i]["residuals"]["v"]
            coef_mat[i] = lasso_reg[i]["coefficients_reg"]
            # selection_matrix[Not(index[i]), i] = lasso_reg[i]["selection_index"]
        end
    end

    residuals = Dict("e" => reside, "v" => residv)
    res = Dict(
        "coefficients" => coefficients, "se" => se, "t" => t, 
        "lasso_reg" => lasso_reg, "index" => index, "sample_size" => n,
        "residuals" => residuals, "coef_mat" => coef_mat, "selection_matrix" => selection_matrix
    )

    return res

end