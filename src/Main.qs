// Distributed implementation of Grover's search algorithm 

namespace DistGrover {
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Diagnostics;
    open DistGates.DistMulticontrol;
    open Microsoft.Quantum.Convert;

    @EntryPoint()
    operation Main(): Result[] {
        // This program will split and run Grover's search algorithm into multiple small-size QPUs
        // using quantum communications to perform collective quantum gates between the QPUs.
        // The program will automatically partition the collective gates into the smallest number of
        // QPUs minimizing the number of ebits.
        //
        // Input parameters:
        //  - target: bitstring to build oracle. Length defines number of computation qubits
        //  - comp_qubits_node: number of computation qubits per QPU
        //  - max_nodes: number of QPUs the algorithm can use at most. It fails if more are required
        //  - single_layer: execute a single layer of Grover's search algorithm, otherwise optimal
        //  - print_state (DEBUG): calls DumpState to print whole state
        //  - verbosity (DEBUG): level of verbosity (0: minimal, 1: standard; 2 debug)
        //
        // Output:
        //  - Result[] found after Grover's search using target to construct oracle


        let target = [
            One, Zero, Zero, One, Zero, Zero, One, One
            ];  // 8-bit string (maximum size if split == False, runs quickly)
        // let target = [
        //     One, Zero, Zero, One, Zero, Zero, One, One, Zero, Zero, One, One
        //     ];  // 12-bit string
        // let target = [
        //     One, Zero, Zero, One, Zero, Zero, One, One, Zero, Zero, One, One,
        //     Zero, Zero, One, Zero, One, Zero
        // ];  // 18-bit string (maximum size if split == True -> very slow!)

        let (comp_qubits_node, max_nodes) = (5, 5);
        let split = true;
        let single_layer = false;
        let print_state = false;
        let verbosity = 1;

        Grover(
            target,
            comp_qubits_node,
            max_nodes,
            split,
            single_layer,
            print_state,
            verbosity
        )
    }

    operation Grover(
            target: Result[],
            comp_qubits_node: Int,
            max_nodes: Int,
            split: Bool,
            single_layer: Bool,
            print_state: Bool,
            verbosity: Int
        ): Result[] {
        // Wrapper for Grover's search using two distributed algorithms

        // Define qubit registers
        use Qubits = Qubit[Length(target)];

        // Set number of layers
        mutable num_layers: Int = 0;
        if single_layer {
            set num_layers = 1;  // FOR DEBUG ONLY
        } else {
            set num_layers = Floor(PI()/4.*Sqrt(2.^IntAsDouble(Length(target)))-0.5);  // Optimal
        }
        Message($"Running distributed Grover's search algorithm with {num_layers} layers");

        let output = runDistGrover(
            Qubits,
            target,
            comp_qubits_node,
            max_nodes,
            num_layers,
            print_state,
            verbosity
        );

        // Reset and free qubits
        ResetAll(Qubits);
        return output
    }

    function Sum(Array: Int[]): Int {
        // Simple summation over an Int array

        mutable sum = 0;
        for i in Array {
            set sum += i
        }
        return sum
    }

    function calc_partition(
            total_qubits: Int,
            qubits_qpu: Int,
            max_qpus: Int,
            verbosity: Int
        ): Int[] {

        // Calculates optimal partition of QPUs
        // Input parameters:
        // - total_qubits: Int -> number of qubits to split across the QPUs
        // - qubits_qpu: Int -> number of qubits that the QPUs have
        // - max_qpus: Int -> maximum number of QPUs
        // - verbosity: Int -> level of verbosity

        // Check that simulation has enough computation qubits, otherwise fail
        if max_qpus*qubits_qpu < total_qubits {
            fail $"Cannot satisfy {total_qubits} in {max_qpus} QPUs of {qubits_qpu} qubits/QPU";
        }

        // Calculate number of nodes needed, up to max_qpus
        let num_nodes = Ceiling(IntAsDouble(total_qubits)/IntAsDouble(qubits_qpu));

        // Ensure the router needed is not larger than the number of nodes, otherwise fail
        if num_nodes > qubits_qpu {
            fail $"Router requires {num_nodes} qubits -> larger than QPUs";
        }

        mutable qubits_left = total_qubits;
        mutable node_qubits = [0, size=num_nodes];
        for i in 0..num_nodes-2 {
            set node_qubits w/= i <- qubits_qpu; 
            set qubits_left -= qubits_qpu;
        }
        set node_qubits w/= num_nodes-1 <- qubits_left;

        if verbosity >= 1 {
            Message($"{num_nodes} nodes required with {node_qubits} computation qubits/node");
        }

        return node_qubits;
    }

    operation runDistGrover(
            Qubits: Qubit[],
            target: Result[],
            computation_qubits_node: Int,
            max_nodes: Int,
            num_layers: Int,
            print_state: Bool,
            verbosity: Int
        ): Result[] {

        // Set maximum number of qubits that can be simulated
        let MAX_QUBITS_SIMULATION = 26;

        // Calculate the lowest ebit cost partition of the algorithm for the input parameters
        let node_qubits = calc_partition(
            Length(target),
            computation_qubits_node,
            max_nodes,
            verbosity);

        // Ensure qubits required fit in memory
        let QUBITS_SIMULATION = (Sum(node_qubits) + 2*Length(node_qubits));
        if QUBITS_SIMULATION > MAX_QUBITS_SIMULATION {
            fail $"Too many qubits: {QUBITS_SIMULATION}";
        }

        if verbosity >= 1 {
            Message($"Length of bitstring: {Length(target)}");
            Message($"Total number of qubits (inc. comm. qubits): {QUBITS_SIMULATION}");
        }

        // Split qubits in nodes
        mutable Nodes = [Qubits[0..-1], size=Length(node_qubits)];
        set Nodes w/= 0 <- Qubits[0.. node_qubits[0]-1];

        for i in 1..Length(node_qubits)-1 {
            set Nodes w/= i <- Qubits[
                Sum(node_qubits[0..i-1]) .. Sum(node_qubits[0..i-1]) + node_qubits[i]-1]
        }

        if verbosity >= 2 {Message($"Nodes: {Nodes}")}

        // Initialise state to |->^(n)
        for q in Qubits {
            X(q); H(q)
        }

        // Execute Grover layer
        for i in 1..num_layers {
            if verbosity >= 1 {Message($"Executing Grover layer {i}/{num_layers}")}

            GroverLayer(Nodes, target, verbosity)
        }

        // Print state (only simulation)
        if print_state {DumpRegister(Qubits)}

        // Measure qubits and compare result with target
        let output = MeasureEachZ(Qubits);
        Message($"Target: {target}");
        Message($"Output: {output}");
        return output
    }

    operation GroverLayer(Nodes: Qubit[][], target: Result[], verbosity: Int): () {
        // Run a single layer of Grover's search. Oracle and diffuser use SplitDistributedMCZ

        let Qubits = Flattened(Nodes);

        // Assert that Flattened(Nodes) and target are of the same length, otherwise fail
        if not (Length(Qubits) == Length(target)) {
            fail $"Length(Qubits) {Length(Qubits)} != Length(target) {Length(target)}";
        }

        // ORACLE
        if verbosity >= 2 {Message($"Executing Oracle")}

        for (q, t) in Zipped(Qubits, target) {if not (t == One) {
            X(q)}  // Flips qubits to construct oracle according to target
        }
        DistributedMCZ(Nodes, verbosity);

        for (q, t) in Zipped(Qubits, target) {if not (t == One) {
            X(q)}  // Undo bit flips according to target
        }

        // DIFFUSER
        if verbosity >= 2 {Message($"Executing Diffuser")}

        for q in Qubits {H(q)}  // Change basis between diffuser and oracle}
        DistributedMCZ(Nodes, verbosity);

        for q in Qubits {H(q)}  // Change basis between diffuser and oracle}
    }
}