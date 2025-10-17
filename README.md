## Distributed Grover's search algorithm implementation
Implementation from the paper I. F. Llovo, G. Díaz-Camacho, N. C. Lago and A. G. Tato, "Network-assisted collective operations for efficient distributed quantum computing," in IEEE Transactions on Quantum Engineering, dx.doi.org/10.1109/TQE.2025.3619387

This program demonstrates splitting and running Grover's search algorithm into multiple small-size QPUs using quantum communications to perform collective quantum gates between the QPUs. The program will automatically partition the collective gates into the smallest number of QPUs minimizing the number of ebits.

### Q# version
Install Q#: https://learn.microsoft.com/en-us/azure/quantum/install-overview-qdk

Input parameters (edit Main.qs)
- target: bitstring to build oracle. Length defines number of computation qubits
- comp_qubits_node: number of computation qubits per QPU
- max_nodes: number of QPUs the algorithm can use at most. It fails if more are required
- single_layer: execute a single layer of Grover's search algorithm, otherwise optimal
- print_state (DEBUG): calls DumpState to print whole state
- verbosity (DEBUG): level of verbosity (0: minimal, 1: standard; 2 debug)

### Qiskit version
A jupyter notebook is provided for demonstration purposes (qiskit >= 1.0)
