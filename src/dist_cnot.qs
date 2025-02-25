namespace DistGates.DistCNOT {
    open Microsoft.Quantum.Arrays;
    open DistGates.Measurements;

    operation DistCNOT(A: Qubit, B: Qubit): () {
        // Distributed CNOT where each of the users, A (Alice) and B (Bob), shares ebit with router

        // Generate ebits:
        // - eA, eB: local part of ebit
        // - RA, RB: router part of ebit
        use (eA, RA) = (Qubit(), Qubit()); H(eA); CNOT(eA, RA);
        use (eB, RB) = (Qubit(), Qubit()); H(eB); CNOT(eB, RB);

        // Entangle local qubits
        CNOT(A, eA); CNOT(eB, B);

        // Apply distributed gates
        CNOT(RA, RB); 

        // Apply corrections
        let (r_rb, r_ea, r_eb, r_ra) = (M(RB), M(eA), MX(eB), MX(RA));
        if XOR([r_rb, r_ea]) {X(B)}
        if XOR([r_eb, r_ra]) {Z(A)}

        // Release ebits
        ResetAll([eA, eB, RA, RB]);
    }

    operation DistCNOTs(C: Qubit[], T: Qubit[]): () {
        // Consecutive distributed CNOTs where each of the users in C and T shares ebit with router

        // Generate ebits:
        // - eC, eT: Qubit[] local part of ebits
        // - RA, RB: Qubit[] router part of ebit
        use (eC, RC) = (Qubit[Length(C)], Qubit[Length(C)]);
        for (c, (e, r)) in Zipped(C, Zipped(eC, RC)) {
            H(e); CNOT(e, r); CNOT(c, e)}
        use (eT, RT) = (Qubit[Length(T)], Qubit[Length(T)]);
        for (t, (e, R)) in Zipped(T, Zipped(eT, RT)) {
            H(e); CNOT(e, R); CNOT(e, t)}

        // Apply distributed gates
        for c in RC {for t in RT {CNOT(c, t)}}

        // Measure ebits
        mutable (r_rc, r_ec) = ([MX(RC[0])], [M(eC[0])]);
        mutable (r_rt, r_et) = ([M(RT[0])], [MX(eT[0])]);
        for (i, (rc, ec)) in Enumerated(Zipped(RC[1...], eC[1...])) {
            set r_rc = Flattened([r_rc, [MX(rc)]]);
            set r_ec = Flattened([r_ec, [M(ec)]]);
            }
        for (i, (rt, et)) in Enumerated(Zipped(RT[1...], eT[1...])) {
            set r_rt = Flattened([r_rt, [M(rt)]]);
            set r_et = Flattened([r_et, [MX(et)]]);
            }

        // Message("Measurement outcomes:");
        // Message($"{r_rc}");
        // Message($"{r_ec}");
        // Message($"{r_rt}");
        // Message($"{r_et}");

        // Apply corrections
        for (i, c) in Enumerated(C) {
            for (j, t) in Enumerated(T) {
                if XOR([r_ec[i], r_rt[j]]) {X(t)}
            }
            if XOR(Flattened([[r_rc[i]], r_et])) {Z(c)}
        }

        // Release ebits
        for (e, r) in Zipped(eC, RC) {ResetAll([e, r])}
        for (e, r) in Zipped(eT, RT) {ResetAll([e, r])}
    }

}