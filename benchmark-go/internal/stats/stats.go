package stats

import (
	"math"
	"sort"
)

type Result struct {
	Mean     float64
	P50      float64
	P95      float64
	Min      float64
	Max      float64
	NSuccess int
	NFailure int
}

func Compute(times []float64, failures int) *Result {
	if len(times) == 0 {
		return nil
	}

	sorted := make([]float64, len(times))
	copy(sorted, times)
	sort.Float64s(sorted)

	n := len(sorted)

	mean := 0.0
	for _, t := range sorted {
		mean += t
	}
	mean /= float64(n)

	p50 := percentile(sorted, 50)
	p95 := percentile(sorted, 95)

	return &Result{
		Mean:     mean,
		P50:      p50,
		P95:      p95,
		Min:      sorted[0],
		Max:      sorted[n-1],
		NSuccess: n,
		NFailure: failures,
	}
}

func percentile(sorted []float64, p float64) float64 {
	n := len(sorted)
	if n == 0 {
		return 0
	}
	if n == 1 {
		return sorted[0]
	}

	rank := (p / 100.0) * float64(n-1)
	lower := int(math.Floor(rank))
	upper := int(math.Ceil(rank))

	if lower == upper {
		return sorted[lower]
	}

	frac := rank - float64(lower)
	return sorted[lower]*(1-frac) + sorted[upper]*frac
}
