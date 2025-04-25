"""
Code that mimicks the behaviour of the stimmulator circuit
"""

constraints = Dict(
    "phase"=>(0, 2pi), 
    "frequency"=>(50, 200),
    "pulse_width"=>(150, 400)
    )

export constraints