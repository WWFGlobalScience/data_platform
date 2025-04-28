library(tidyverse)
library(readxl)
library(ggrepel)

setwd("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy")
gov <- read_xlsx(path = "Governance_Indicators.xlsx")

countries <- c("Colombia")

cpi <- gov[,c(1,4:15)]

colnames(cpi) <- c("Country", 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023)

cpi <- cpi %>% pivot_longer(cols = -Country, names_to = "Year", values_to = "Value")

cpi$Year <- as.numeric(cpi$Year)

cpi_labels <- cpi %>%
  group_by(Country) %>%
  filter(Year == min(Year)+1)

cpi <- cpi %>% filter(Country %in% countries)
cpi_labels <- cpi_labels %>% filter(Country %in% countries)

cpi_plot <- ggplot(cpi, aes(x = Year, y = Value, color = Country, group = Country)) +
  geom_line() +
  geom_point() +
  geom_label_repel(data = cpi_labels, aes(label = Country),
                  nudge_x = 0.5, # Slight horizontal nudging
                  nudge_y = 0.5,
                  alpha = 0.8,
                  size = 4,
                  fill = "white",
                  segment.color = NA,
                  box.padding = 0.3, # Space between text and box
                  point.padding = 0.9, # Space between point and text
                  max.overlaps = Inf) + 
  labs(title = "Corruption Perception Index",
       y = "Index Score\n(0 = Highly corrupt, 100 = Minimally corrupt)",
       caption = "Source: Transparency International")+
  theme_bw() +
  theme(legend.position = "none", axis.title.x = element_blank())

cpi_plot

