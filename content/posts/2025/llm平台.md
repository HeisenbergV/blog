---
title: "LLM平台"
categories: [coder]
tags: [AI]
date: 2025-04-07
---


## LLM应用开发平台是什么
LLM: LLM的全称是 ​​Large Language Model（大语言模型）​​，专指通过海量文本数据训练、能理解和生成自然语言的超大规模人工智能模型

LLM平台（如Dify/FastGPT）: 本质上是通过工程化手段，把"零散的Prompt技巧"和"业务需求"组合成可复用的AI产品​​。可以理解为LLM平台 = 模型 + 代码 + 工程化"全家桶"​


## 简单举例
1. 传统编码时代（手写逻辑）​
```go
// 程序员明确定义计算规则
// 优点：绝对可控  缺点：只能处理预设情况
func sum(a, b int) int {
    return a + b
}

// 调用示例
result := sum(1, 2) // 永远返回3
```

2. 直接调用模型API（通用但原始）​
```python
# 把计算任务丢给AI，但需处理非结构化返回
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "请问1+2等于多少？"}]
)
# 实际返回可能是：
# "1+2等于3" → 需用正则提取数字
# 或错误回复："这是小学数学题，答案是3"
```

​3. LLM平台时代（工程化解决方案）​
```yaml
# 在Dify/FastGPT等平台配置：
steps:
  - type: "math_operation"
    inputs: ["num1", "num2"]
    template: "计算{{num1}} + {{num2}}的精确值"
    output_type: "number"  # 强制返回数字而非文本
    error_fallback: "调用本地计算函数"  # 降级方案

# 最终调用方式（平台生成的标准API）
POST /api/calculate 
{"num1": 1, "num2": 2} → 返回 {"result": 3}

```

| 维度 | 手写函数 | 裸调API | LLM平台 |
|------|----------|---------|----------|
| 开发速度 | 快（简单逻辑） | 中（需处理文本解析） | 最快（可视化配置） |
| 灵活性 | 只能处理预设输入 | 可处理模糊自然语言 | 平衡结构化与灵活性 |
| 维护成本 | 需修改代码 | 需持续优化Prompt | 后台热更新配置 |
| 适用场景 | 确定性强的基础运算 | 探索性需求 | 生产环境复杂AI应用 |

## LLM平台适用场景
> 我从日本买了一个价值200美元的智能手表，寄到中国海南自贸港，请问要交多少关税？有没有免税政策？

基于这个问题我们用三种方式来开发:
### 传统编码
很难实现，需要调用各种接口，确认各种数据，另外也无法识别用户的文字描述，只能从输入源限制用户的格式
```go
// 传统编码方式 - 关税计算服务
type TaxCalculator struct {
    // 数据库连接
    db *sql.DB
    // 汇率服务
    exchangeService *ExchangeService
    // 海关编码服务
    customsCodeService *CustomsCodeService
}

func (tc *TaxCalculator) CalculateTax(item string, price float64, from string, to string) (float64, error) {
    // 1. 获取商品海关编码
    code, err := tc.customsCodeService.GetCode(item)
    if err != nil {
        return 0, fmt.Errorf("获取海关编码失败: %v", err)
    }

    // 2. 查询税率
    taxRate, err := tc.db.Query("SELECT rate FROM tax_rates WHERE code = ?", code)
    if err != nil {
        return 0, fmt.Errorf("查询税率失败: %v", err)
    }

    // 3. 汇率转换
    exchangeRate, err := tc.exchangeService.GetRate("USD", "CNY")
    if err != nil {
        return 0, fmt.Errorf("获取汇率失败: %v", err)
    }

    // 4. 计算关税
    tax := price * exchangeRate * taxRate

    // 5. 检查特殊政策（如海南自贸港）
    if to == "海南" {
        specialPolicy, err := tc.db.Query("SELECT discount FROM special_policies WHERE region = ?", "海南")
        if err == nil && specialPolicy > 0 {
            tax = tax * (1 - specialPolicy)
        }
    }

    return tax, nil
}

// 痛点：
// 1. 代码复杂，需要维护多个服务
// 2. 政策变化需要修改代码
// 3. 无法处理自然语言输入
// 4. 错误处理复杂
```

### 利用AI模型
```python
# 直接调用AI模型的方式
import openai
from typing import Dict, Any

class AITaxCalculator:
    def __init__(self, api_key: str):
        self.client = openai.OpenAI(api_key=api_key)
        
    def calculate_tax(self, question: str) -> Dict[str, Any]:
        try:
            response = self.client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": "你是一个专业的关税计算助手"},
                    {"role": "user", "content": question}
                ],
                temperature=0.7,
                max_tokens=500
            )
            
            # 解析返回结果
            result = response.choices[0].message.content
            
            # 尝试提取数字
            import re
            tax_amount = re.search(r'\d+\.?\d*', result)
            
            return {
                "raw_response": result,
                "tax_amount": float(tax_amount.group()) if tax_amount else None,
                "explanation": result
            }
            
        except Exception as e:
            return {
                "error": str(e),
                "tax_amount": None,
                "explanation": "计算失败"
            }

# 使用示例
calculator = AITaxCalculator("your-api-key")
result = calculator.calculate_tax("我从日本买了一个价值200美元的智能手表，寄到中国海南自贸港，请问要交多少关税？")
print(result)

# 缺陷：
# 1. 无法保证返回格式统一
# 2. 可能返回过时信息
# 3. 没有数据验证
# 4. 无法对接实时数据库
```

### 基于LLM平台
```python
# LLM平台配置示例（以Dify为例）
{
    "name": "关税计算助手",
    "description": "智能计算跨境商品关税",
    "prompt_template": """
    你是一个专业的关税计算助手。请根据以下信息计算关税：
    商品：{{item}}
    价值：{{value}}美元
    起运地：{{from}}
    目的地：{{to}}
    
    请按照以下步骤计算：
    1. 确定商品海关编码
    2. 查询适用税率
    3. 考虑特殊政策（如自贸区）
    4. 计算最终税额
    """,
    "variables": {
        "item": {"type": "string", "required": true},
        "value": {"type": "number", "required": true},
        "from": {"type": "string", "required": true},
        "to": {"type": "string", "required": true}
    },
    "tools": [
        {
            "name": "查询海关编码",
            "type": "api",
            "config": {
                "url": "https://customs-api.com/code",
                "method": "POST",
                "params": {
                    "item": "{{item}}"
                }
            }
        },
        {
            "name": "查询税率",
            "type": "api",
            "config": {
                "url": "https://customs-api.com/rate",
                "method": "GET",
                "params": {
                    "code": "{{海关编码}}"
                }
            }
        },
        {
            "name": "检查特殊政策",
            "type": "api",
            "config": {
                "url": "https://customs-api.com/policy",
                "method": "GET",
                "params": {
                    "region": "{{to}}"
                }
            }
        }
    ],
    "output_template": """
    根据计算结果：
    商品海关编码：{{海关编码}}
    适用税率：{{税率}}%
    特殊政策：{{特殊政策}}
    最终税额：{{税额}}元
    """
}

# 平台生成的API调用示例
import requests

def calculate_tax(item: str, value: float, from_region: str, to_region: str) -> dict:
    response = requests.post(
        "https://llm_api.com/api/tax-calculator",
        json={
            "item": item,
            "value": value,
            "from": from_region,
            "to": to_region
        },
        headers={"Authorization": "Bearer token"}
    )
    return response.json()

# 使用示例
result = calculate_tax(
    item="智能手表",
    value=200,
    from_region="日本",
    to_region="海南"
)
print(result)

# 优势：
# 1. 统一的输入输出格式
# 2. 可配置的工具链
# 3. 实时数据支持
# 4. 易于维护和更新
```

## 总结

目前大部分非AI的系统平台需要为用户提供界面，让用户基于固定形式来输入各种参数才能完成一系列的工作。现在有了AI模型可以让用户傻瓜式的输入一些话来达到目标，而有了LLM平台不但让用户可以傻瓜式的使用，还能约束AI模型的输入输出。

1. **传统系统**
   - 用户需要学习复杂的界面操作
   - 输入必须符合严格的格式要求
   - 功能扩展需要修改代码

2. **AI模型直接调用**
   - 用户可以用自然语言描述需求
   - 但输出结果不可控
   - 无法保证数据准确性和实时性

3. **LLM平台**
   - 结合了前两者的优势
   - 用户可以用自然语言交互
   - 平台确保输出符合业务规范
   - 可以对接实时数据和业务系统
