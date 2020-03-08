library(tidyverse)
library(compiler)

# Load data
data <- read_csv("data/HDA_data.csv")

# Transform data to appropriate type by describing categorical features
mm_data <- data %>%
  mutate(AWEEKEND=factor(AWEEKEND, labels=c("weekday", "weekend"), levels=c(0,1)),
         DISPUNIFORM=factor(DISPUNIFORM, labels=c("routine","short term hosp", "other", "home care", "against medical adv", "died in hosp", "alive, unknown dest"), levels=c(1,2,5,6,7,20,99)),
         FEMALE=factor(FEMALE, labels=c("male", "female"), levels=c(0,1)),
         HCUP_ED=ifelse(HCUP_ED>0, 1, HCUP_ED),
         HCUP_ED=factor(HCUP_ED, labels=c("no", "yes"), levels=c(0,1)),
         ORPROC=factor(ORPROC, labels=c("no","yes"), levels=c(0,1)),
         PAY1=factor(PAY1, labels=c("Medicare", "Medicaid"), levels=c(1,2)),
         PL_NCHS=factor(PL_NCHS, labels=c("central metro >1m", "fringe metro >1m", "counties metro 250-999k", "counties metro 50-250k", "micro counties", "other"), levels=c(1,2,3,4,5,6)),
         REHABTRANSFER=factor(REHABTRANSFER, labels=c("no", "yes"), levels=c(0,1)),
         SAMEDAYEVENT=ifelse(SAMEDAYEVENT>0, 1, SAMEDAYEVENT),
         SAMEDAYEVENT=factor(SAMEDAYEVENT, labels=c("no","yes"), levels=c(0,1)),
         ZIPINC_QRTL=factor(ZIPINC_QRTL, labels=c("1-40k", "40-51k", "51-66k", ">66k"), levels=c(1,2,3,4)),
         APRDRG_Risk_Mortality=factor(APRDRG_Risk_Mortality, labels=c("unknown", "minor", "moderate", "major", "extreme"), levels=c(0,1,2,3,4)),
         APRDRG_Severity=factor(APRDRG_Severity, labels=c("unknown", "minor", "moderate", "major", "extreme"), levels=c(0,1,2,3,4))) %>%
  mutate_at(vars(CM_AIDS:CM_WGHTLOSS), funs(factor(., labels=c(0,1), levels=c("no","yes"))))

# Calculate days between discharge and subsequent admission to determine if patient is readmitted within 30 days
# Function to calculate days between discharge and subsequent admission
readmission_days <- function(dataset){
  output <- numeric(nrow(dataset)-1)
  for (i in 1:(nrow(dataset)-1)){
    output[i] <- dataset$NRD_DaysToEvent[i]-dataset$NRD_DaysToEvent[i+1]-dataset$LOS[i+1] 
  }
  readm2 <- cbind(dataset[1:(nrow(dataset)-1),],output)
  return(readm2)
}
# Compile function to byte code to speed up computation
myfun <- cmpfun(readmission_days)
# Apply function on dataset
df <- myfun(mm_data)
# Average days between admission for each patient and indicate if patient is readmitted
readmission <- df %>%
  mutate(output=abs(output)) %>%
  arrange(NRD_VisitLink, desc(output)) %>%
  group_by(NRD_VisitLink) %>%
  filter(duplicated(NRD_VisitLink)|n()==1) %>%
  arrange(NRD_VisitLink, desc(NRD_DaysToEvent)) %>%
  rename ("Days_Between_Readmission"="output")
avg_readm <- readmission %>%
    group_by(NRD_VisitLink) %>%
    summarise("Average_Readmission_Days"=round(mean(Days_Between_Readmission),1)) %>%
    mutate(Readmit_30=as.factor(ifelse(Average_Readmission_Days<=30,1,0)))

# Write output to csv file
write_csv(avg_readm,"data/processed_data.csv")



