namespace DistGates.Measurements {
    open Microsoft.Quantum.Arrays;

    operation MX(q: Qubit): Result {
        H(q); M(q)
    }

    function XOR(r: Result[]): Bool {
        // Make results of type Bool
        mutable bool_results = [r[0] == One];
        for ri in r[1...] {set bool_results = Flattened([bool_results, [ri == One]])}

        // Count how many results are true; even returns false, odd returns true
        let num_true = Count(x -> x == true, bool_results);
        if (num_true % 2 == 1) {
            return true;
        } else {
            return false;
        }
    }

}
