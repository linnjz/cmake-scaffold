#include <benchmark/benchmark.h>

#include <cstddef>
#include <cstdint>
#include <vector>

namespace {
std::uint64_t sum(const std::vector<std::uint64_t>& values)
{
    std::uint64_t total = 0;
    for (const auto value : values)
    {
        total += value;
    }
    return total;
}
} // namespace

static void BM_VectorSum(benchmark::State& state)
{
    const auto size = static_cast<std::size_t>(state.range(0));
    const std::vector<std::uint64_t> values(size, 1);

    for ([[maybe_unused]] auto _ : state)
    {
        benchmark::DoNotOptimize(sum(values));
    }

    state.SetItemsProcessed(state.iterations() * static_cast<std::int64_t>(values.size()));
}

BENCHMARK(BM_VectorSum)->Arg(1024)->Arg(65536);
