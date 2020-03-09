library(psych)
library(tidyverse)
library(gmodels)
library(caret)
library(ROCR)
library(C50)

# Load data
full_dat1 <- read_csv("data/engineered_data.csv")

# Rename columns
dat_r <- na.omit(full_dat1 %>%
                   select(-c(NRD_VisitLink, Average_Readmission_Days))) %>%
  rename(
    "Discharge_month"="DMONTH",
    "Length_of_stay"="LOS",
    "Number_chronic"="NCHRONIC",
    "Number_procedure"="NPR",
    "Use_operating_room"="ORPROC",
    "Severity"="APRDRG_Severity",
    "Chronic_lung"="CM_CHRNLUNG",
    "Diabetes"="CM_DMCX",
    "Cancer"="CM_METS",
    "Neurological_disorder"="CM_NEURO",
    "Paralysis"="CM_PARA",
    "Tumor"="CM_TUMOR",
    "Weightloss"="CM_WGHTLOSS",
    "Anemia_deficiency"="CM_ANEMDEF"
  ) %>%
  mutate(Length_of_stay=(Length_of_stay)^(1/3),
         Number_procedure=(Number_procedure^(2/5)))

# Split data into training and testing sets
size <- nrow(dat_r) * 0.75
train_dat <- dat_r[1:size,] 
test_dat <- dat_r[(size+1):nrow(dat_r),]

# Logistic regression model in trained on all features and each feature that is not statistically significant is removed (backward elimination) until we have statistically significant features remaining that contribute to the model.

# Remove unimportant features determined by backward elimination
dat_r1 <- train_dat %>%
  select(-c(CM_OBESE, CM_PERIVASC,CM_ALCOHOL, CM_LYMPH, LOCATION, CM_LIVER, CM_COAG, INCOME_QRTL, CM_DRUG, CM_BLDLOSS, NDX, CM_DEPRESS, CM_VALVE, CM_PSYCH, CM_RENLFAIL, CM_HTN_C, CM_AIDS, SAMEDAYEVENT, TOTCHG, CM_ULCER, CM_HYPOTHY, HCUP_ED, CM_LYTES, CM_PULMCIRC, REHABTRANSFER, APRDRG_Risk_Mortality, CM_ARTH, AWEEKEND, CM_CHF)) 

# Train logistic regression model on statistically significant features
m <- glm(Readmit_30~DISPOSITION+AGE+Discharge_month+I(Discharge_month^2)+Length_of_stay+Number_chronic+Number_procedure+Use_operating_room+Severity+Anemia_deficiency+Chronic_lung+Diabetes+Cancer+Neurological_disorder+Paralysis+Tumor+Weightloss, data=dat_r1, family="binomial")

# Evaluate model performance
p <- predict(m, test_dat, type="response")
predicted1 <- as.matrix(data.frame("predict_Readmit_30"=ifelse(p>0.5,1,0)))
original <- test_dat %>%
  select(Readmit_30) %>%
  mutate_all(as.character) %>%
  mutate_all(as.numeric) %>%
  as.matrix()
CrossTable(predicted1, original,prop.chisq = F, prop.c = F, prop.r=F)
(accuracy <- round(length(which(original==predicted1))/length(predicted1),2))
confusionMatrix(predicted1, original)
pr <- prediction(predicted1, original)
prf <- performance(pr, measure="tpr", x.measure="fpr")
plot(prf)
auc <- performance(pr, measure = "auc")
auc <- auc@y.values[[1]]

# Train decision tree model
n <- sample(nrow(train_dat), 5000)
train <- train_dat[n,] %>%
  mutate(Readmit_30=factor(Readmit_30, labels=c("yes","no"), levels=c(1,0))) %>%
  select(-c(LOCATION, INCOME_QRTL, AWEEKEND, HCUP_ED, DISPOSITION))

## Assign more weight to false negative predictions

## Creates 2x2 matrix
matrix_dimensions <- list(c("yes", "no"), c("yes", "no"))
names(matrix_dimensions) <- c("predicted","actual")
## Assigns cost
error_cost <- matrix(c(0,3,1,0), nrow=2, dimnames=matrix_dimensions)
error_cost

model <- C5.0(train[,setdiff(colnames(train),"Readmit_30")], train$Readmit_30, costs=error_cost)

# Evaluate model performance 
test <- train_dat[-n,] %>%
slice(1:500) %>%
  mutate(Readmit_30=factor(Readmit_30, labels=c("yes","no"), levels=c(1,0)))
p_model <- predict(model, test)
confusionMatrix(p_model, test$Readmit_30)
CrossTable(p_model, test$Readmit_30, prop.chisq = F, prop.c = F, prop.r=F)

pred_d <- ifelse(p_model=="yes",1,0)
orig_d <- ifelse(test$Readmit_30=="yes",1,0)
pr_d <- prediction(pred_d, orig_d)
prf_d <- performance(pr_d, measure="tpr", x.measure="fpr")
auc_d <- performance(pr_d, measure = "auc")
auc_d <- auc_d@y.values[[1]]
round(auc_d,2)