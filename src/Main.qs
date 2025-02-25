// Distributed implmentation of Grover's search algorithm 

namespace DistGrover {
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Diagnostics;
    open DistGates.DistCNOT;
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
        //  - target: sequence to build Grover's oracle. Length defines number of computation qubits
        //  - comp_qubits_node: number of computation qubits per QPU
        //  - comm_qubits_node: (not implemented) number of communication qubits per QPU
        //  - max_nodes: number of QPUs the algorithm can use at most. It fails if more are required
        //  - split: set to False to use 1 comp qubits + 1 comm qubits per node (e.g., NV-centers)
        //      overrides comp_qubits_node, comm_qubits_node and max_nodes
        //  - print_state: calls DumpState to print whole state. Only possible in simulation
        //
        // Output:
        //  - Result[] found after Grover's search using target to construct oracle

        // let target = [
        //     One, Zero, Zero, One, Zero, Zero, One, One,
        //     Zero, Zero, One, One, Zero, Zero, One, Zero
        // ];
        
        let target = [
            One, Zero, Zero, One, Zero, Zero, One, One, Zero
        ];

        let (comp_qubits_node, comm_qubits_node, max_nodes) = (3, 1, 3);
        let split = true;
        let print_state = false;

        Grover(target, comp_qubits_node, comm_qubits_node, max_nodes, split, print_state)
    }

    operation Grover(
        target: Result[],
        comp_qubits_node: Int,
        comm_qubits_node: Int,
        max_nodes: Int,
        split: Bool,
        print_state: Bool): Result[] {

        // Wrapper for Grover's search using two distributed algorithms:
        //  - if split == true -> use comp_qubits_node + comm_qubits_node qubits per node
        //  - else -> use 1 comp qubits + 1 comm qubits per node (e.g., NV-centers)

        use Qubits = Qubit[Length(target)];

        mutable output = [Zero, size=Length(target)];
        if split {
            // Run Grover with comp_qubits_node qubits per node
            set output = runDistGroverSplit(
                Qubits, target, comp_qubits_node, comm_qubits_node, max_nodes, print_state);
        } else {
            // Run Grover con 1 comp qubit + 1 comm qubit per node
            set output = runDistGrover(Qubits, target, print_state);
        }

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

    function calc_partition(total_qubits: Int, qubits_qpu: Int, max_qpus: Int): Int[] {
        // Calculates optimal partition of QPUs
        // Inputs:
        //  - total_qubits: number of qubits to split across the QPUs
        //  - qubits_qpu: number of qubits that the QPUs have
        //  - max_qpus: maximum number of 

        if max_qpus*qubits_qpu < total_qubits {
            fail $"Cannot satisfy {total_qubits} in {max_qpus} QPUs of {qubits_qpu} qubits/QPU";
        }

        let num_nodes = Ceiling(IntAsDouble(total_qubits)/IntAsDouble(qubits_qpu));

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

        Message($"{num_nodes} nodes required");
        Message($"{node_qubits} qubits in each node");

        return node_qubits;
    }

    operation runDistGrover(Qubits: Qubit[], target: Result[], print_state: Bool): Result[] {
        // Set number of layers
        // let num_layers = 1;  // FOR DEBUG ONLY
        let num_layers = Floor(PI()/4.*Sqrt(2.^IntAsDouble(Length(Qubits)))-0.5);  // Optimal
        Message($"Running Grover's search algorithm with {num_layers} layers");

        for q in Qubits {
            X(q); H(q)
        }
        for l in 1..num_layers {
            GroverLayer(Qubits, target)
        }

        // Print state (only simulation)
        if print_state {DumpRegister(Qubits)}

        // Measure qubits and compare result with target
        let output = MeasureEachZ(Qubits);
        Message($"Target: '{target}'");
        return output
    }

    operation runDistGroverSplit(
            Qubits: Qubit[],
            target: Result[],
            computation_qubits_node: Int,
            communication_qubits_node: Int,
            max_nodes: Int,
            print_state: Bool): Result[] {

        // Set maximum number of qubits that can be simulated
        let MAX_QUBITS_SIMULATION = 25;

        // Calculate the lowest ebit cost partition of the algorithm for the input parameters
        let node_qubits = calc_partition(Length(Qubits), computation_qubits_node, max_nodes);

        // Ensure qubits required fit in memory
        let QUBITS_SIMULATION = (Sum(node_qubits) + Length(node_qubits)*communication_qubits_node);
        if QUBITS_SIMULATION > MAX_QUBITS_SIMULATION {
            fail $"Too many qubits: {QUBITS_SIMULATION}";
        }

        // Set number of layers
        // let num_layers = 1;  // FOR DEBUG ONLY
        let num_layers = Floor(PI()/4.*Sqrt(2.^IntAsDouble(Length(Qubits)))-0.5);  // Optimal
        Message($"Running Grover's search algorithm with {num_layers} layers");

        // Split qubits in nodes
        mutable Nodes = [Qubits[0..-1], size=Length(node_qubits)];
        set Nodes w/= 0 <- Qubits[0.. node_qubits[0]-1];
        Message($"Node 0 - {node_qubits[0]} qubits: {Nodes[0]}");
        for i in 1..Length(node_qubits)-1 {
            set Nodes w/= i <- Qubits[
                Sum(node_qubits[0..i-1]) .. Sum(node_qubits[0..i-1]) + node_qubits[i]-1]
        }
        Message($"{Nodes}");

        // Initialise state to |->^(n)
        for q in Qubits {
            X(q); H(q)
        }

        for i in 1..num_layers {
            GroverLayerSplit(Nodes, target)
        }

        // Print state (only simulation)
        if print_state {DumpRegister(Qubits)}

        // Measure qubits and compare result with target
        let output = MeasureEachZ(Qubits);
        Message($"Target: '{target}'");
        return output
    }

    operation GroverLayer(Qubits: Qubit[], target: Result[]): () {
        // Run a single layer of Grover's search. Oracle and diffusor use DistMCZ

        // Assert that Qubit and target are of the same length, otherwise fail
        if not (Length(Qubits) == Length(target)) {
            fail $"Length(Qubits) {Length(Qubits)} != Length(target) {Length(target)}";
        }

        // Oracle
        for (q, t) in Zipped(Qubits, target) {if not (t == One) {
            X(q)}  // Flips qubits to construct oracle according to target
        }
        DistMCZ(Qubits);

        for (q, t) in Zipped(Qubits, target) {
            if not (t == One) {
                X(q)  // Undo bit flips according to target
            }
            H(q)  // Change basis between oracle and diffusor
        }

        // Diffusor
        DistMCZ(Qubits);
        for q in Qubits {
            H(q)  // Change basis between diffusor and oracle
        }
    }

    operation GroverLayerSplit(Nodes: Qubit[][], target: Result[]): () {
        // Run a single layer of Grover's search. Oracle and diffusor use SplitDistributedMCZ

        let Qubits = Flattened(Nodes);

        // Assert that Flattened(Nodes) and target are of the same length, otherwise fail
        if not (Length(Qubits) == Length(target)) {
            fail $"Length(Qubits) {Length(Qubits)} != Length(target) {Length(target)}";
        }

        // Oracle
        for (q, t) in Zipped(Qubits, target) {if not (t == One) {
            X(q)}  // Flips qubits to construct oracle according to target
        }
        SplitDistributedMCZ(Nodes);

        for (q, t) in Zipped(Qubits, target) {
            if not (t == One) {
                X(q)  // Undo bit flips according to target
            }
            H(q)  // Change basis between oracle and diffusor
        }

        // Diffusor
        SplitDistributedMCZ(Nodes);
        for q in Qubits {
            H(q)  // Change basis between diffusor and oracle
        }
    }
}