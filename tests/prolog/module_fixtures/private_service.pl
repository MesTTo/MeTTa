% Purpose: declare a callable core service that its facade does not export.
% Guarantees: the service census detects the missing host publication.
% [tested: engine_modules:the_service_census_sees_a_declared_private_predicate; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]

:- module(plunit_module_private_service, []).

seam:kind('$metta_module_private_service'/0, host_service).
metta_engine:'$metta_module_private_service'.
