module;

#include <cmath>
#include <limits>

module math;

constexpr auto math::sqrt(double value, double tolerate) noexcept -> double
{
  if (value < 0) return std::numeric_limits<double>::quiet_NaN();

  double guess = value * .5;
  double prev  = 0.;
  while (std::abs(prev - guess) > tolerate) {
    prev  = guess;
    guess = (guess + value / guess) * .5;
  }
  return guess;
}