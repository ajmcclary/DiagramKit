wardley-beta
title Pipeline Evolution
component Compute [0.5, 0.6]
pipeline Compute {
  component Virtual Machine [0.3]
  component Container [0.55]
  component Serverless [0.8]
}
Compute -> Virtual Machine
