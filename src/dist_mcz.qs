namespace DistGates.DistMulticontrol {
    open DistGates.Measurements;
    open Microsoft.Quantum.Arrays;

    operation DistMCZ(Qubits: Qubit[]): Result[][] {
        // Distributed CC··Z where each of the users shares ebit with router 

        // Generate ebits:
        // - epr{C1, C2, T}: local part of ebit
        // - R{C1, C2, T}: router part of ebit
        use (EPR_user, EPR_router) = (Qubit[Length(Qubits)], Qubit[Length(Qubits)]);
        for (e, r) in Zipped(EPR_user, EPR_router) {H(e); CNOT(e, r)}

        // Entangle local qubits
        for (q, (e, r)) in Zipped(Qubits, Zipped(EPR_user, EPR_router)) {
            Controlled Z([q], e); H(r);
        }

        // Apply first corrections
        mutable meas_epr: Result[] = [Zero, size=Length(Qubits)];
        for (i, (e, r)) in Enumerated(Zipped(EPR_user, EPR_router)) {
            set meas_epr w/= i <- MX(e);
            if (meas_epr[i] == One) {X(r)}
        }

        // Apply distributed gate
        Controlled Z(Qubits[0 .. Length(Qubits)-2], Qubits[Length(Qubits)-1]);

        mutable meas_router: Result[] = [Zero, size=Length(Qubits)];
        for (i, (q, r)) in Enumerated(Zipped(Qubits, EPR_router)) {
            set meas_router w/= i <- MX(r);
            if (meas_router[i] == One) {Z(q)}
        }

        // Release ebits
        ResetAll(EPR_user);
        ResetAll(EPR_router);
        return [meas_epr, meas_router]
    }

    operation SplitDistributedMCZ(Nodes: Qubit[][]): Result[][] {
        // Collective CC··Z where each of the nodes shares one ebit with router 

        // Generate ebits:
        // - epr{C1, C2, T}: local part of ebit
        // - R{C1, C2, T}: router part of ebit

        mutable CommQubits = [Nodes[0][0], size=Length(Nodes)];
        mutable meas_epr: Result[] = [Zero, size=Length(CommQubits)];
        mutable meas_router: Result[] = [Zero, size=Length(CommQubits)];

        for (i, n) in Enumerated(Nodes) {
            set CommQubits w/= i <- n[0]
        }
        Message($"Distributed MCZ between qubits {CommQubits}");

        use (EPR_user, EPR_router) = (Qubit[Length(CommQubits)], Qubit[Length(CommQubits)]);
        for (e, r) in Zipped(EPR_user, EPR_router) {H(e); CNOT(e, r)}

        // Entangle local qubits
        for (n, (e, r)) in Zipped(Nodes, Zipped(EPR_user, EPR_router)) {
            Controlled Z(n, e); H(r);
        }

        // Apply first corrections
        for (i, (e, r)) in Enumerated(Zipped(EPR_user, EPR_router)) {
            set meas_epr w/= i <- MX(e);
            if (meas_epr[i] == One) {X(r)}
        }

        // Apply distributed gate
        Controlled Z(EPR_router[1...], EPR_router[0]);

        for (i, (n, r)) in Enumerated(Zipped(Nodes, EPR_router)) {
            set meas_router w/= i <- MX(r);
            if (meas_router[i] == One) {
                Controlled Z(n[1...], n[0]);
            }
        }

        // Release ebits
        ResetAll(EPR_user);
        ResetAll(EPR_router);
        return [meas_epr, meas_router]
    }
}