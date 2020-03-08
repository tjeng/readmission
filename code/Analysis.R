library(tidyverse)

# Load data
data <- read_csv("/data/processed_data.csv")

# Investigating how clinical conditions affect 30-day readmission.

## Method: Perform hypothesis testing to determine if the proportion of patient who are readmitted vs those who are not differs for each clinical condition and visualize results

cond <- dat_r %>%
  filter(!is.na(Readmit_30)) %>%
  group_by(Readmit_30) %>%
  select(Anemia_deficiency, Chronic_lung, Diabetes, Cancer, Neurological_disorder, Paralysis, Tumor, Weightloss) %>%
  summarize_all(mean)

for (i in colnames(cond)[2:ncol(cond)]){
  dat <- dat_r %>%
    filter(!is.na(Readmit_30)) %>%
    group_by(Readmit_30) %>%
    select(i)
  print(list(i,t.test(subset(dat,Readmit_30==0)[[2]],subset(dat,Readmit_30==1)[[2]],alternative=c("two.sided"))))
}

conditions <- c("Anemia deficiency", "Chronic lung disease", "Diabetes complications", "Cancer", "Neurological disorder", "Paralysis", "Tumor", "Weightloss")

n_not30 <- nrow(dat_r %>%
                  filter(Readmit_30==0)) 
n_30 <- nrow(dat_r %>%
               filter(Readmit_30==1)) 

# Function to calculate standard error
se <- function(x,n){
  return(sqrt((x*(1-x))/n))
}

df_cond <- data.frame(Conditions=conditions)
for (i in 1:(length(cond)-1)){
  df_cond$Not_Readmit_30[i] <- cond[[i+1]][1]
  df_cond$ci_not_30[i] <- 2*se(df_cond$Not_Readmit_30[i],n_not30)
  df_cond$Readmit_30[i] <- cond[[i+1]][2]
  df_cond$ci_30[i] <- 2*se(df_cond$Readmit_30[i],n_30)
}

df_cond1 <- df_cond %>%
  gather(Not_Readmit_30, Readmit_30, key=`Readmit`,value=`Percentage`) %>%
  gather(ci_not_30, ci_30, key=`Readmit1`, value=`CI`) %>%
  slice(1:(2*length(conditions)))

# Visualize results
ggplot(df_cond1,aes(x=Conditions, y=Percentage, fill=Readmit)) + 
  geom_bar(position=position_dodge(), stat="identity") +
  geom_errorbar(aes(ymin=Percentage-CI, ymax=Percentage+CI),
                width=0.2,
                position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.title=element_blank()) +
  ylab("Average Proportion") 


# Investigating how disposition (care after discharge) affects 30-day readmission

## Method: Perform hypothesis testing to determine if the proportion of patient who are readmitted vs those who are not differs for each disposition and visualize results

for (i in 1:(length(unique(dat_r$DISPOSITION))-1)){
  dat <- dat_r %>%
    filter(!is.na(Readmit_30)) %>%
    group_by(Readmit_30) %>%
    select(DISPOSITION,Readmit_30) %>%
    mutate(DISPOSITION=ifelse(DISPOSITION==as.character(unique(dat_r$DISPOSITION)[i]),1,0))
  print (list(as.character(unique(dat_r$DISPOSITION)[i]),t.test(DISPOSITION~Readmit_30,data=dat)))
}


nd_not30<- nrow(dat_r %>%
                  filter(!is.na(DISPOSITION), Readmit_30==0))
nd_30 <- nrow(dat_r %>%
                filter(!is.na(DISPOSITION), Readmit_30==1))

disp <- dat_r %>%
  filter(!is.na(DISPOSITION), !is.na(Readmit_30)) %>%
  select(DISPOSITION, Readmit_30) %>%
  mutate(Readmit_30=factor(Readmit_30, labels=c("Not_Readmit_30","Readmit_30"), levels=c(0,1))) %>%
  group_by(Readmit_30) %>%
  count(DISPOSITION) %>%
  mutate(Proportion=ifelse(Readmit_30=="Not_Readmit_30",(n/nd_not30),(n/nd_30)),
         CI=ifelse(Readmit_30=="Not_Readmit_30", (2*se(Proportion,nd_not30)),(2*se(Proportion, nd_30)))) %>%
  select(-n)

ggplot(disp, aes(x=DISPOSITION, y=Proportion, fill=Readmit_30)) +
  geom_bar(position="dodge",stat="identity") +
  geom_errorbar(aes(ymin=Proportion-CI, ymax=Proportion+CI),
                width=0.25,
                position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.title = element_blank()) +
  xlab("Disposition") +
  ylab("Average Proportion") 


# Investigating how season affects patient readmission

## Method: First, convert month to season. Next, conduct the following statistical analysis: ANOVA to determine if season and readmission are related, two sample t-test to determine if proportion of patient readmission differ between 2 seasons, and one-sample t-test to determine if proportion of patient readmission in the data set is significantly different from the national average. Finally, visualize the data.

# Convert month to day and manipulate data for visualization
season <- dat_r %>%
  select(Discharge_month, Readmit_30) %>%
  mutate(#Readmit_30=as.numeric(levels(Readmit_30)[Readmit_30]),
    Discharge_month=cut(Discharge_month, seq(1,13,1), right=F, labels=c(1:12)),
    Season=ifelse(Discharge_month %in% c(12,1,2),"Winter", ifelse(Discharge_month %in% c(3:5), "Spring", ifelse(Discharge_month %in% c(6:8), "Summer", "Fall"))),
    Season=as.factor(Season)) %>%
  filter(!is.na(Readmit_30)) 

cnt_season <- season %>% group_by(Season) %>% count()
winter <- (cnt_season %>% filter(Season=="Winter"))$n
summer <- (cnt_season %>% filter(Season=="Summer"))$n
spring <- (cnt_season %>% filter(Season=="Spring"))$n
fall <- (cnt_season %>% filter(Season=="Fall"))$n

readm_season <- season %>%
  group_by(Season) %>%
  summarise(Proportion=mean(Readmit_30)) %>%
  mutate(CI=ifelse(Season=="Winter",(2*se(Proportion,winter)),ifelse(Season=="Summer", (2*se(Proportion,summer)), ifelse(Season=="Spring", (2*se(Proportion,spring)), (2*se(Proportion,fall))))))

#ANOVA test
an <- aov(Readmit_30~Season, data=season)
summary(an)
# Two-sample t-test between pair of season
winter_fall <- season %>% filter(Season=="Winter"|Season=="Fall") 
t.test(Readmit_30~Season, winter_fall)
summer_fall <- season %>% filter(Season=="Summer"|Season=="Fall") 
t.test(Readmit_30~Season, summer_fall)
spring_fall <- season %>% filter(Season=="Spring"|Season=="Fall") 
t.test(Readmit_30~Season, spring_fall)
summer_winter <- season %>% filter(Season=="Winter"|Season=="Summer") 
t.test(Readmit_30~Season, summer_winter)
winter_spring <- season %>% filter(Season=="Winter"|Season=="Spring") 
t.test(Readmit_30~Season, winter_spring)
summer_spring <- season %>% filter(Season=="Summer"|Season=="Spring") 
t.test(Readmit_30~Season, summer_spring)
# One-sample t-test
t.test(season$Readmit_30,mu=0.29)

# Generate graph
ggplot(readm_season, aes(x=reorder(Season, -Proportion), y=Proportion)) +
  geom_bar(stat="identity", aes(fill=Season)) +
  guides(fill=F) +
  geom_errorbar(aes(ymin=Proportion-CI, ymax=Proportion+CI),
                width=0.1,
                position=position_dodge(.9)) +
  geom_hline(yintercept=0.29) + 
  annotate(geom="text", x=3.5, y=0.32,label="data avg=0.29") +
  geom_hline(yintercept=0.20, colour="red") + 
  annotate(geom="text", x=3.5, y=0.23,label="national avg=0.2", colour="red") +
  xlab("Season") + ylab("Average Proportion")

