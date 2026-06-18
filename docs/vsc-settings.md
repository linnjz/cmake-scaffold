### 核心语义令牌类型列表

下表是根据 C/C++ 扩展官方文档整理的完整令牌类型及其说明：

| 令牌类型 (Token Type)    | 说明                                  | 对应的 Fallback TextMate Scope               |
| ------------------------ | ------------------------------------- | -------------------------------------------- |
| `templateType`           | 类模板 (Class Template)               | `entity.name.type.class.templated`           |
| `enumMember`             | 枚举成员 (Enumerator)                 | `variable.other.enummember`                  |
| `event`                  | 事件 (C++/CLI)                        | `variable.other.event`                       |
| `function`               | 函数 (Function)                       | `entity.name.function`                       |
| `templateFunction`       | 函数模板 (Function Template)          | `entity.name.function.templated`             |
| `genericType`            | 泛型类型 (C++/CLI)                    | `entity.name.type.class.generic`             |
| `variable.global`        | 全局变量 (Global Variable)            | `variable.other.global`                      |
| `label`                  | 标签 (Label)                          | `entity.name.label`                          |
| `variable.local`         | 局部变量 (Local Variable)             | `variable.other.local`                       |
| `macro`                  | 宏 (Macro)                            | `entity.name.function.preprocessor`          |
| `property`               | 成员字段 (Member Field)               | `variable.other.property`                    |
| `method`                 | 成员函数 (Member Function)            | `entity.name.function.member`                |
| `namespace`              | 命名空间 (Namespace)                  | `entity.name.namespace`                      |
| `newOperator`            | new / delete 操作符                   | `keyword.operator.new`                       |
| `operatorOverload`       | 操作符重载函数                        | `entity.name.function.operator`              |
| `memberOperatorOverload` | 成员操作符重载                        | `entity.name.function.operator.member`       |
| `parameter`              | 参数 (Parameter)                      | `variable.parameter`                         |
| `cliProperty`            | 属性 (C++/CLI)                        | `variable.other.property.cli`                |
| `referenceType`          | 引用类型 (C++/CLI)                    | `entity.name.type.class.reference`           |
| `property.static`        | 静态成员字段 (Static Member Field)    | `variable.other.property.static`             |
| `method.static`          | 静态成员函数 (Static Member Function) | `entity.name.function.member.static`         |
| `type`                   | 类型 (Type)                           | `entity.name.type`                           |
| `numberLiteral`          | 用户定义字面量 - 数字                 | `entity.name.operator.custom-literal.number` |
| `customLiteral`          | 用户定义字面量 - 原始                 | `entity.name.operator.custom-literal`        |
| `stringLiteral`          | 用户定义字面量 - 字符串               | `entity.name.operator.custom-literal.string` |
| `valueType`              | 值类型 (C++/CLI)                      | `entity.name.type.class.value`               |

> **注意**：`macro` 和 `preprocessor`（预处理指令）在较新版本中可能被区分开来。表中未列出的 `preprocessor` 类型也可能有效。