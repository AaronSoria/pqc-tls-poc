package stats

import (
	"math"
	"sort"
)

// Result holds aggregate statistics for a slice of measurements.
type Result struct {
	Mean     float64
	P50      float64
	P95      float64
	Min      float64
	Max      float64
	NSuccess int
	NFailure int
}

// PhaseTimings holds per-iteration phase breakdown for a single handshake (ms).
type PhaseTimings struct {
	Init      float64 // library / config setup
	Dial      float64 // TCP connect
	Handshake float64 // pure TLS negotiation
	Total     float64 // wall-clock total
}

// PhaseResult holds P50/P95/mean for a single phase.
type PhaseResult struct {
	Mean float64
	P50  float64
	P95  float64
}

// DetailedResult extends Result with per-phase statistics.
type DetailedResult struct {
	Result
	Init      PhaseResult
	Dial      PhaseResult
	Handshake PhaseResult
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
	return &Result{
		Mean:     mean,
		P50:      percentile(sorted, 50),
		P95:      percentile(sorted, 95),
		Min:      sorted[0],
		Max:      sorted[n-1],
		NSuccess: n,
		NFailure: failures,
	}
}

func ComputeDetailed(phases []PhaseTimings, failures int) *DetailedResult {
	if len(phases) == 0 {
		return nil
	}
	totals := make([]float64, len(phases))
	inits := make([]float64, len(phases))
	dials := make([]float64, len(phases))
	handshakes := make([]float64, len(phases))
	for i, p := range phases {
		totals[i] = p.Total
		inits[i] = p.Init
		dials[i] = p.Dial
		handshakes[i] = p.Handshake
	}
	dr := &DetailedResult{}
	dr.Result = *Compute(totals, failures)
	dr.Init = computePhase(inits)
	dr.Dial = computePhase(dials)
	dr.Handshake = computePhase(handshakes)
	return dr
}

func computePhase(vals []float64) PhaseResult {
	sorted := make([]float64, len(vals))
	copy(sorted, vals)
	sort.Float64s(sorted)
	mean := 0.0
	for _, v := range sorted {
		mean += v
	}
	mean /= float64(len(sorted))
	return PhaseResult{
		Mean: mean,
		P50:  percentile(sorted, 50),
		P95:  percentile(sorted, 95),
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
