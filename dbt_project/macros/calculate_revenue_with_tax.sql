{% macro calculate_revenue_with_tax(revenue_column, tax_rate=0.0) %}
    /*
    Calculate revenue including tax.

    Args:
        revenue_column: Column name containing base revenue
        tax_rate: Tax rate as decimal (default 0.0 for demo - no tax)

    Returns:
        Revenue with tax applied

    Example:
        {{ calculate_revenue_with_tax('order_total', 0.08) }}
    */
    {{ revenue_column }} * (1 + {{ tax_rate }})
{% endmacro %}
