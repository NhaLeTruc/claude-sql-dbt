{% macro calculate_days_between(start_date, end_date) %}
    /*
    Calculate the number of days between two dates.

    Args:
        start_date: Starting date (earlier date)
        end_date: Ending date (later date)

    Returns:
        Integer representing days between dates

    Example:
        {{ calculate_days_between('first_order_date', 'last_order_date') }}
    */
    EXTRACT(DAY FROM {{ end_date }}::timestamp - {{ start_date }}::timestamp)
{% endmacro %}
