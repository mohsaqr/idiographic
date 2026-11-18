library(idiographic)
options(width = 120)
srl <- read.csv("../data/srl_learners.csv")
described <- describe_persons(srl, id = "name", vars = c("efficacy", "effort"), time = "day",
                              detail = "full")
as.data.frame(described)
result <- subset(transform(described, series = paste(subject, variable)), select = -c(subject, variable))
