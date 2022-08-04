{{ config(materialized='view') }}

{#-
    setting vars used in for loops
-#}
{% set table_list = [
      'eligibility'
    , 'medical_claim'
] -%}

/*
    loop through all tables and columns for general checks
*/
with general_checks as (

    {%- for table_item in table_list %}

        {%- set current_table = var( table_item ) -%}

        {%- set all_columns = adapter.get_columns_in_relation(
            current_table
        ) -%}

        {%- for column_item in all_columns %}

            select
                  '{{ table_item }}' as table_name
                , '{{ column_item.name|lower }}' as column_name
                , '{{ column_item.data_type }}' as data_type
                , (select count(*)::integer as cnt
                   from {{ current_table }}
                  ) as table_total
                , (select max(len( {{ column_item.name }} ))::integer as cnt
                   from {{ current_table }}
                  ) as max_column_length
                , (select count(*)::integer as cnt
                   from {{ current_table }}
                   where {{ column_item.name }} is null

                        {# missing/null logic for specific claim types -#}

                        {% if column_item.name.lower() == 'bill_type_code' -%}
                            and upper(claim_type) = 'I'
                        {%- endif -%}

                        {% if column_item.name.lower() == 'discharge_disposition_code' -%}
                            and upper(claim_type) = 'I'
                        {%- endif -%}

                        {% if column_item.name.lower() == 'revenue_center_code' -%}
                            and upper(claim_type) = 'I'
                        {%- endif -%}

                        {% if column_item.name.lower() == 'place_of_service_code' -%}
                            and upper(claim_type) = 'P'
                        {%- endif -%}

                  ) as missing_values
                , (select count(*)::integer as cnt
                   from {{ current_table }}
                   where {{ column_item.name }}::varchar = ''
                  ) as blank_values
                , (select count(distinct {{ column_item.name }} )::integer as ct
                   from {{ current_table }}
                  ) as unique_values

            {% if not loop.last -%}
                union all
            {%- endif -%}

            {%- endfor -%}

        {% if not loop.last -%}
            union all
        {%- endif -%}

    {%- endfor -%}

)

select
      table_name
    , column_name
    , data_type
    , table_total
    , max_column_length
    , missing_values
    , blank_values
    , unique_values
from general_checks