"""
Functions contained in this file mimicks the behaviour of a brain. Naturally,
this will be replaced by the recording/stim board in real-life experiments.
"""
using Distributions 

"This generates coefficients to parameterise James Mason's model of the brain"
function initialise_objective_func()
    coefficients = Dict(
        "phase"=>zeros(3), 
        "frequency"=>zeros(3),
        "pulse_width"=>zeros(3)
        )
    
        coefficients.phase = (Uniform(0, 1), Uniform(0, 1), Uniform(0, 2pi))   
        coefficients.frequency = (Uniform(-2, 0), Uniform(5e-6, 5e-5), Uniform(50, 200))   
        coefficients.pulse_width = (Uniform(-.2, 0), Uniform(1e-6, 1e-5), Uniform(150, 400))   

        return coefficients
end

function evaluate_objective_func(coefficients, x)

    m, a, b = coefficients.phase
    phase_component = m*(a*sin(x[1]+ b) + (1-a)*sin(2*x[1]+b))

    a, b, s = coefficients.frequency
    freq_component = 1 + a + b(x[2]-s)^2

    a, b, s = coefficients.pulse_width
    pw_components = 1 + a + b(x[2]-s)^2

    result = phase_component*freq_component*pw_components

    return result
end