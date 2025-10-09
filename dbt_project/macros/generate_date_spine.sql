{% macro generate_date_spine(start_date, end_date) %}
    /*
    Generate a complete date spine using dbt_utils.

    Args:
        start_date: Starting date (format: 'YYYY-MM-DD')
        end_date: Ending date (format: 'YYYY-MM-DD')

    Returns:
        CTE with all dates in range

    Example:
        {{ generate_date_spine('2022-01-01', '2024-12-31') }}
    */
    {{
        dbt_utils.date_spine(
            datepart="day",
            start_date="cast('" ~ start_date ~ "' as date)",
            end_date="cast('" ~ end_date ~ "' as date)"
        )
    }}
{% endmacro %}
