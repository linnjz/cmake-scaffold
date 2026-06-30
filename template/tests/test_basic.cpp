#include <cstdlib>
#include <iostream>

namespace {
constexpr int add(int lhs, int rhs)
{
    return lhs + rhs;
}
} // namespace

int main()
{
    constexpr int result = add(40, 2);
    if (result != 42)
    {
        std::cerr << "expected 42, got " << result << '\n';
        return EXIT_FAILURE;
    }

    std::cout << "test_basic: ok\n";
    return EXIT_SUCCESS;
}
