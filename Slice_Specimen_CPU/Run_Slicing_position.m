clear all;
clc;
na = 5; nb = 5; nc = 5; PotPar = 6; ncu = 4; sigma = 0.285;
tic;
[Atomsi, lx, ly, lz, a, b, c, dz] = Au001Crystal(na, nb, nc, ncu, sigma);
toc;
Dim = 111; Seed = 1983; inFP = 2;
tic;
[Atoms, Slice] = getSliceSpecimen(Atomsi, lx, ly, dz, inFP, Dim, Seed);
toc;
S = getAtomTypes(PotPar);
z0 = min(Atoms(:, 3))-S(Atoms(1,4)).Rmax;
ze = max(Atoms(:, 3))+S(Atoms(end,4)).Rmax;
[nAtoms,~] = size(Atoms);
[nSlice, ~] = size(Slice)

xy = zeros(nAtoms, 2);
xy(:, 2) = Atoms(:, 3);
figure(1); clf;
plot(xy(:, 1), xy(:, 2), '*b');
hold on;
plot([-1 1], [z0 z0], '-k','LineWidth',3);
hold on;
plot([-1 1], [ze ze], '-k','LineWidth',3);
for i = 1:nSlice
    hold on;
    plot([-1 1], [Slice(i, 1) Slice(i, 1)], '-r');
    set(gca,'FontSize',10,'LineWidth',1,'PlotBoxAspectRatio',[0.75 1 1]);
end;
hold on;
plot([-1 1], [Slice(i, 2) Slice(i, 2)], '-r');
