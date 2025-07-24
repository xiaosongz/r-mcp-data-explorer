#' Data Exploration Prompts
#' Provides guided workflows for data analysis

#' Get data exploration prompt
#' @param dataset_path Path to dataset file
#' @return List of messages for prompt
get_explore_data_prompt <- function(dataset_path) {
  messages <- list()
  
  # System message
  messages[[1]] <- list(
    role = "system",
    content = "You are a data analysis assistant specializing in R and tidyverse. 
You will help users explore their data using the available MCP tools:
- load_data: Load datasets from files
- run_tidyverse: Execute R code with tidyverse
- query_duckdb: Run SQL queries on loaded data

Guide the user through a comprehensive data exploration workflow."
  )
  
  # User message
  messages[[2]] <- list(
    role = "user", 
    content = sprintf("I want to explore the dataset at: %s

Please help me:
1. Load and understand the structure of this data
2. Check data quality (missing values, duplicates, outliers)
3. Generate summary statistics and visualizations
4. Identify interesting patterns or relationships
5. Provide insights and recommendations for further analysis", dataset_path)
  )
  
  # Assistant message with workflow
  messages[[3]] <- list(
    role = "assistant",
    content = "I'll help you explore your dataset comprehensively. Let me start by loading the data and understanding its structure.

## Step 1: Load the Data
First, I'll load your dataset and examine its basic properties."
  )
  
  return(messages)
}

#' Get analysis workflow prompts
get_analysis_prompts <- function() {
  list(
    # EDA workflow
    eda = list(
      name = "exploratory_data_analysis",
      description = "Comprehensive exploratory data analysis workflow",
      steps = c(
        "Load and inspect data structure",
        "Check data types and missing values", 
        "Generate summary statistics",
        "Create distribution plots for numeric variables",
        "Analyze categorical variables",
        "Explore correlations and relationships",
        "Identify outliers and anomalies",
        "Create key visualizations"
      )
    ),
    
    # Time series workflow
    time_series = list(
      name = "time_series_analysis",
      description = "Time series data analysis workflow",
      steps = c(
        "Identify date/time columns",
        "Check time series continuity",
        "Aggregate by time periods",
        "Calculate moving averages",
        "Detect trends and seasonality",
        "Create time series visualizations",
        "Forecast future values"
      )
    ),
    
    # Comparison workflow
    comparison = list(
      name = "group_comparison", 
      description = "Compare groups or categories in data",
      steps = c(
        "Identify grouping variables",
        "Calculate group statistics",
        "Test for significant differences",
        "Create comparison visualizations",
        "Analyze group distributions",
        "Identify group patterns"
      )
    ),
    
    # Data quality workflow
    quality = list(
      name = "data_quality_check",
      description = "Comprehensive data quality assessment",
      steps = c(
        "Check for missing values",
        "Identify duplicates",
        "Validate data types",
        "Check value ranges",
        "Identify outliers",
        "Assess data consistency",
        "Generate quality report"
      )
    )
  )
}

#' Generate code snippets for common tasks
get_code_snippets <- function() {
  list(
    # Data inspection
    glimpse = "glimpse(data)",
    
    summary = "summary(data)",
    
    structure = "str(data)",
    
    head = "head(data, 10)",
    
    # Missing values
    missing_count = "data %>% 
  summarise(across(everything(), ~sum(is.na(.)))))",
    
    missing_viz = "data %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = 'column', values_to = 'missing') %>%
  ggplot(aes(x = reorder(column, missing), y = missing)) +
  geom_col() +
  coord_flip() +
  labs(title = 'Missing Values by Column')",
    
    # Summary statistics
    numeric_summary = "data %>%
  select(where(is.numeric)) %>%
  summary()",
    
    group_summary = "data %>%
  group_by({group_var}) %>%
  summarise(
    count = n(),
    across(where(is.numeric), list(mean = mean, sd = sd), na.rm = TRUE)
  )",
    
    # Distributions
    histogram = "data %>%
  ggplot(aes(x = {numeric_var})) +
  geom_histogram(bins = 30, fill = 'steelblue', alpha = 0.7) +
  labs(title = 'Distribution of {numeric_var}')",
    
    density = "data %>%
  ggplot(aes(x = {numeric_var})) +
  geom_density(fill = 'steelblue', alpha = 0.5) +
  labs(title = 'Density Plot of {numeric_var}')",
    
    boxplot = "data %>%
  ggplot(aes(x = {group_var}, y = {numeric_var})) +
  geom_boxplot(fill = 'steelblue', alpha = 0.7) +
  labs(title = '{numeric_var} by {group_var}')",
    
    # Relationships
    scatter = "data %>%
  ggplot(aes(x = {x_var}, y = {y_var})) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = 'lm', se = TRUE) +
  labs(title = 'Relationship between {x_var} and {y_var}')",
    
    correlation = "data %>%
  select(where(is.numeric)) %>%
  cor(use = 'complete.obs')",
    
    pairs = "data %>%
  select(where(is.numeric)) %>%
  sample_n(min(1000, nrow(.))) %>%
  GGally::ggpairs()",
    
    # Time series
    time_plot = "data %>%
  ggplot(aes(x = {date_var}, y = {value_var})) +
  geom_line() +
  geom_smooth(method = 'loess', se = TRUE) +
  labs(title = '{value_var} Over Time')",
    
    # Categorical
    bar_chart = "data %>%
  count({cat_var}) %>%
  ggplot(aes(x = reorder({cat_var}, n), y = n)) +
  geom_col(fill = 'steelblue') +
  coord_flip() +
  labs(title = 'Count by {cat_var}')",
    
    # Data cleaning
    remove_duplicates = "data %>%
  distinct()",
    
    filter_missing = "data %>%
  filter(!is.na({column}))",
    
    impute_mean = "data %>%
  mutate({column} = ifelse(is.na({column}), mean({column}, na.rm = TRUE), {column}))"
  )
}

#' Generate prompt for specific analysis type
#' @param analysis_type Type of analysis
#' @param dataset_name Name of loaded dataset
#' @return Formatted prompt
generate_analysis_prompt <- function(analysis_type, dataset_name) {
  prompts <- get_analysis_prompts()
  
  if (!analysis_type %in% names(prompts)) {
    return(NULL)
  }
  
  workflow <- prompts[[analysis_type]]
  
  # Build prompt
  lines <- character()
  lines <- c(lines, paste0("## ", workflow$description))
  lines <- c(lines, "")
  lines <- c(lines, paste0("I'll guide you through a ", analysis_type, 
                          " workflow for the '", dataset_name, "' dataset."))
  lines <- c(lines, "")
  lines <- c(lines, "Here are the steps we'll follow:")
  
  for (i in seq_along(workflow$steps)) {
    lines <- c(lines, paste0(i, ". ", workflow$steps[i]))
  }
  
  lines <- c(lines, "")
  lines <- c(lines, "Let's start with step 1...")
  
  return(paste(lines, collapse = "\n"))
}