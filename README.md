Install Q#: https://learn.microsoft.com/en-us/azure/quantum/install-overview-qdk

This program will split and run Grover's search algorithm into multiple small-size QPUs
using quantum communications to perform collective quantum gates between the QPUs.
The program will automatically partition the collective gates into the smallest number of
QPUs minimizing the number of ebits.

Input parameters (edit Main.qs)
  - target: sequence to build Grover's oracle. Length defines number of computation qubits
  - comp_qubits_node: number of computation qubits per QPU
  - comm_qubits_node: (not implemented) number of communication qubits per QPU
  - max_nodes: number of QPUs the algorithm can use at most. It fails if more are required
  - split: set to False to use 1 comp qubits + 1 comm qubits per node (e.g., NV-centers)
       overrides comp_qubits_node, comm_qubits_node and max_nodes
  - print_state: calls DumpState to print whole state. Only possible in simulation

Output:
  - Result[] found after Grover's search using target to construct oracle
