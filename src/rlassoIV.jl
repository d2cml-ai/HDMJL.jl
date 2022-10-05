mutable struct rlassoIV1
    se
    sample_size
    #vcov
    coefficients
    dict
end

function rlassoIV(x, d, y, z; select_Z::Bool = true, select_X::Bool = true, post::Bool = true)
    if !select_Z & !select_X
        res = tsls(d, y, z, x, homoskedastic = false)
        se = res["se"]
        
    elseif select_Z & !select_X
        res = rlassoIVselectZ(x, d, y, z, post = post)
        res["sample_size"] = size(x)[1]
        
    elseif !select_Z & select_X
        res = rlassoIVselectX(x, d, y, z, post = post)
        res["sample_size"] = size(x)[1]
        
    elseif select_Z & select_X
        
        Z = hcat(z, x)
        lasso_d_zx = rlasso(Z, d, post = post)
        lasso_y_x = rlasso(x, y, post = post)
        lasso_d_x = rlasso(x, d, post = post)
        if sum(lasso_d_zx["index"]) == 0
            print("No variables in the Lasso regression of d on z and x selected")
            return Dict("alpha" => nan, "se" => nan)
        end
        ind_dzx = lasso_d_zx["index"]
        PZ = d - lasso_d_zx["residuals"]
        lasso_PZ_x = rlasso(x, PZ, post = post)
        ind_PZx = lasso_PZ_x["index"]
        
        if sum(ind_PZx) == 0
            Dr = d .- mean(d)
        else
            Dr = d .- (PZ - lasso_PZ_x["residuals"])
        end
        
        if sum(lasso_y_x["index"]) == 0
            Yr = y .- mean(y)
        else
            Yr = lasso_y_x["residuals"]
        end
        
        if sum(lasso_y_x["index"]) == 0
            Zr = PZ .- mean(x)
        else
            Zr = lasso_PZ_x["residuals"]
        end
        
        res = tsls(Dr, Yr, Zr, intercept = false, homoscedastic = false)
    end
    se = res["se"]
    sample_size = res["sample_size"]
    #vcov = res["vcov"]
    coefficients = res["coefficients"]
    res1 = rlassoIV1(se, sample_size, coefficients, res);
    return res1;
end

function r_print(object::rlassoIV1, digits = 3)
    if length(object.coefficients) !=  0
        b = ["X$y" for y = length(object.coefficients)]
        b = reshape(b,(1,length(b)))
        a = vcat(b, round.(object.coefficients', digits = 3))
        if length(object.coefficients) <= 10
            
            println("Coefficients:\n")
            pretty_table(a[2,:]', tf = tf_borderless, header = a[1,:])
        else 
            for i in 1:trunc(length(object.coefficients)/10)
                pretty_table(a[2,10*(i-1)+1:10*i]', tf = tf_borderless, header = a[1,10*(i-1)+1:10*i])
            end
        pretty_table(a[2,10*trunc(length(object.coefficients)/10)+1:length(object.coefficients)]',
                            tf = tf_borderless, header = a[1,10*trunc(length(object.coefficients)/10)+1:length(object.coefficients)])
        end
    else 
        print("No coefficients\n")
    end
end

using Distributions
function r_summary(object::rlassoIV1)
    if length(object.coefficients) != 0
        k = length(object.coefficients)
        table = zeros(k, 4)
        table[:, 1] .= object.coefficients
        table[:, 2] .= object.se
        table[:, 3] .= table[:, 1]./table[:, 2]
        table[:, 4] .= 2 * cdf(Normal(), -abs.(table[:, 3]))
        table1 = DataFrame(table, :auto)
        table1 = rename(table1, ["coeff.", "se.", "t-value", "p-value"])
        print("Estimates and Significance Testing of the effect of target variables in the IV regression model", 
                "\n")
        pretty_table(table, show_row_number = true, header = ["coeff.", "se.", "t-value", "p-value"], tf = tf_borderless)
        print("---", "\n", "Signif. codes:","\n", "0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1")
        print("\n")
        return table1;
    else
        print("No coefficients\n")
        #table = []
    end
    #return table;;
end

function r_confint(object::rlassoIV1, level = 0.95)
    n = object.sample_size
    k = length(object.coefficients)
    cf = object.coefficients
    #pnames <- names(cf)
    # if (missing(parm)) 
    #     parm <- pnames else if (is.numeric(parm)) 
    #       parm <- pnames[parm]
    a = (1 - level)/2
    a = [a, 1 - a]
    fac = quantile.(Normal(), a)
    pct = string.(round.(a; digits = 3)*100, "%")
    ses = object.se
    c_i = []
    for i in 1:length(cf)
        if i == 1
            c_i = (cf[i] .+ ses[i] .* fac)[:,:]'
        else
            c_i = vcat(c_i, (cf[i] .+ ses[i] .* fac)[:,:]')
        end
    end
    table1 = DataFrame(c_i, :auto)
    table1 = rename(table1, pct)
    #ci = NamedArray(c_i, (1:size(c_i)[1], pct))
    ci = pretty_table(c_i; header = pct, show_row_number = true, tf = tf_borderless)
    return table1;
end