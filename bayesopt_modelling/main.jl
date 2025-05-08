using brain
using stimulator

# Parameters for simulation 
memory_size = 9
num_iter = 200

# Variable initialisation 
memory = zeros(memory_size, 4) # 4 is number of dimensions (3) + number of outputs (1)
should_stop  = false

# Generate coefficients for test objective function
coefficients = initialise_objective_func()

# Generate initial samples 
initial_samples = (
    LinRange(constraints.phase..., memory_size),
    LinRange(constraints.frequency..., memory_size),
    LinRange(constraints.pulse_width..., memory_size)
)

# Main loop to optimise the stimulation frequency
while !should_stop
    # Fit a GP to data
    pred
    # Acqusition function 

    # Evaluate fitness of new x

    # Update variable beta

    # Update memory
end

