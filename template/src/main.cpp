import std;
using std::literals::string_view_literals::operator""sv;

template<class T>
struct MyType
{
  using type = T;
};

enum class Color : int
{
  Red,
  Green,
  Blue
};

consteval auto pow2(size_t base, size_t exp) noexcept -> size_t
{
  if (!base) return base;
  std::uint64_t res { 1 };
  while (exp) {
    if (exp & 1) res *= base;
    exp /= 2;
    base *= base;
  }
  return res;
}

constexpr auto my_ipow(size_t base, size_t exp) noexcept -> size_t
{
  if /*not*/ consteval {
    return pow2(base, exp);
  } else {
    return std::pow(base, exp);
  }
}

void func()
{
  {
    // std::forward_like<Owner>(member) 的含义是——“如果 Owner 是 const 左值，就把 member 当作 const 左值；
    // 如果 Owner 是 mutable 右值，就把 member 当作 mutable 右值”。它把外部容器的“身份特征”强制投射到内部成员上。

    /*
      ### 1. 它解决了什么问题？（核心痛点）

      在 C++20 及之前，当你试图在泛型代码中完美转发“对象的成员”时，会遇到严重缺陷。文档中提到了三种模型，而 `std::forward_like` 解决的就是 **“language” 模型（即 `std::forward<decltype(o)>(o).m`）无法正确处理“远对象”（Far Objects）** 的问题。

      具体场景如下：

      - **场景一：智能指针（如 `std::unique_ptr`）**
        当你对 `unique_ptr` 调用 `*ptr` 时，它**永远返回左值**（即使 `unique_ptr` 本身是右值）。如果使用 `std::forward<decltype(owner)>(owner).ptr`，解引用后依然得到左值，无法将“所有者是右值”这一信息传递进去，导致无法移动内部资源。

      - **场景二：容器的下标访问（如 `vector::operator[]`）**
        标准库容器通常**不提供右值引用版本的 `operator[]`**（返回 `T&&`）。如果你对临时容器执行 `std::forward<decltype(v)>(v)[0]`，仍然只能得到左值，无法触发移动语义。

      - **场景三：`std::optional` 的 `.value()`**
        虽然 `optional` 提供了右值重载，但某些自定义包装器或代理对象不会提供。

      **`std::forward_like` 的解法**：它不依赖于成员访问操作符本身的返回类型，而是**在拿到成员后，直接强制转换其结果**。例如，即使 `*ptr` 返回左值，`forward_like<decltype(owner)>(*ptr)` 会强行将其转成右值（如果 `owner` 是右值）或加上 const（如果 `owner` 是 const）。这相当于给成员访问结果套了一层“伪装”，完美保留了所有者的值类别。

      ---

      ### 2. 与 `std::forward` 的核心区别

      | 对比维度 | `std::forward<T>(arg)` | `std::forward_like<T>(x)` |
      | :--- | :--- | :--- |
      | **模板参数含义** | `T` 是 **`arg` 本身的“伪装”类型**（通常来自推导）。 | `T` 是 **“所有者（Owner）”的类型**，而 `x` 是被转发的成员。 |
      | **参照依据** | 依据 `T` 来决定 `arg` 是左值还是右值（标准转发语义）。 | 依据 `T` 的 const 限定和值类别，**强制应用**到 `x` 上。 |
      | **底层模型** | **Language 模型**（保持传入时的原始值类别）。 | **Merge 模型**（合并所有者的 const + 所有者的值类别）。 |
      | **典型使用姿势** | `std::forward<T>(arg)`（`arg` 就是 `T` 类型的变量）。 | `std::forward_like<decltype(owner)>(owner.member)`（关注的是外层的 `owner`）。 |
      | **能否改变结果的值类别** | 不能改变函数/操作符返回的固有值类别，只能按参数原本的类别转发。 | **可以强行改变**。即使 `x` 天生是左值，只要 `T` 是右值引用，`forward_like` 就会返回右值引用。 |

      ---

      ### 一句话总结

      - **`std::forward`**：用于**函数参数**的传递，保留参数自身原本的左/右值属性。
      - **`std::forward_like`**：用于**对象成员/解引用结果**的传递，**忽略成员自身的原有属性**，强制让它表现得像外层容器对象一样（保持 const 一致性和值类别一致性）。

      这就是为什么文档示例中，即使 `unique_ptr` 解引用永远是左值，`forward_like` 依然能在 `std::move(my_state).from_ptr()` 时输出 `mutable rvalue` —— 它成功地将“所有者是右值”这个信息强制赋予了成员。这在编写泛型包装器（如代理类、观察器）时至关重要。
      */
  }

  {
    {
      constexpr auto value = my_ipow(2, 2);
      static_assert(value == 4);
    }

    {
      size_t base = 2, exp = 2;
      auto value = my_ipow(base, exp);
    }
  }

  {
    static_assert(std::is_scoped_enum_v<Color>); // ::
    (void) std::is_constant_evaluated();
    (void) std::endian::native;
    (void) std::make_shared_for_overwrite<double[][4]>(4);
    alignas(256) std::array<std::type_identity_t<MyType<int>>, 256> arr;
    auto const *arr_ptr = std::assume_aligned<256>(arr.data());
    std::move_only_function<void()> f =
        std::move([ptr = std::make_unique_for_overwrite<int[]>(4)]() { });

    std::string s;
    s.resize_and_overwrite(
        10, [](char *buf, size_t buf_size)
    {
      int written = std::snprintf(buf, buf_size, "World!??");
      return static_cast<size_t>(written);
    });
  }

  {
    std::list<int> l(10);
    std::iota(l.begin(), l.end(), -4);
    std::vector<std::reference_wrapper<int>> v(l.begin(), l.end());
    static_assert(
        std::same_as<std::unwrap_reference_t<std::reference_wrapper<int>>, int &>);
  }

  {
    struct string_hash
    {
      using is_transparent = void; // 关键标记：启用异构查找

      std::size_t operator() (std::string_view const sv) const noexcept
      {
        return std::hash<std::string_view> {}(sv);
      }
    };

    std::unordered_map<std::string, int, string_hash, std::equal_to<>> map;
    (void) map.find("123"sv);
  }
}

auto main() -> int
{
  std::println("{}", 42);
  return 0;
}
