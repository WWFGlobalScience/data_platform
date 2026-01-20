library(tidyverse)
library(readxl)
library(ggrepel)

setwd("C:/Users/readd/Documents/WWF_Consultancy/2024-25_Consultancy")
ppl <- read_xlsx(path = "People_Indicators.xlsx")

countries <- c("Bolivia", "Brazil", "Paraguay")

mwash <- ppl[,c(1,4)]

colnames(mwash) <- c("Country", "2019")

mwash <- mwash %>% pivot_longer(cols = -Country, names_to = "2019", values_to = "Value")

mwash$Value <- as.numeric(mwash$Value)

mwash <- mwash %>% filter(Country %in% countries)

mwash_plot <- ggplot(mwash) +
  geom_col(aes(y=Value, x = Country, fill = Country)) +
  labs(title = "Mortality due to Unsafe Water or Lack of Sanitation or Hygiene",
       y = "Deaths per 100,000 people",
       caption = "Source: World Health Organization")+
  theme_bw() +
  theme(legend.position = "none", axis.title.x = element_blank())

mwash_plot
