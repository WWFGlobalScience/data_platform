library(tidyverse)
library(readxl)
library(ggrepel)

setwd("C:/Users/readd/Documents/WWF_Consultancy/2024-25_Consultancy")
ppl <- read_xlsx(path = "People_Indicators.xlsx")

countries <- c("Madagascar")

pov <- ppl[,c(1,48:58)]

colnames(pov) <- c("Country", 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022)

pov <- pov %>% pivot_longer(cols = -Country, names_to = "Year", values_to = "Value")

pov$Value <- as.numeric(pov$Value)
pov$Year <- as.numeric(pov$Year)

pov_labels <- pov %>%
  group_by(Country) %>%
  filter(Year == min(Year)+1)

pov <- pov %>% filter(Country %in% countries)
pov_labels <- pov_labels %>% filter(Country %in% countries)

pov_plot <- ggplot(pov, aes(x = Year, y = Value, color = Country, group = Country)) +
  geom_line() +
  geom_point() +
  geom_label_repel(data = pov_labels, aes(label = Country),
                   nudge_x = 0.5, # Slight horizontal nudging
                   nudge_y = 0.5,
                   alpha = 0.8,
                   size = 4,
                   fill = "white",
                   segment.color = NA,
                   box.padding = 0.3, # Space between text and box
                   point.padding = 0.9, # Space between point and text
                   max.overlaps = Inf) + 
  labs(title = "Poverty Rate",
       y = "Percent of Population\nliving with < $2.15/day",
       caption = "Source: World Bank")+
  theme_bw() +
  scale_x_continuous(limits = c(2012, 2022), n.breaks = 6)+
  theme(legend.position = "none", axis.title.x = element_blank())

pov_plot
